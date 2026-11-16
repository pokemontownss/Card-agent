// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAgentId {
    function balanceOf(address account) external view returns (uint256);
}

/// @title AgentCard (ACARD) — engraved Agent ID Cards on BNB Chain.
/// @notice ERC-721 mint contract matching the public site spec (agentcard.cloud):
/// - MAX_SUPPLY 2,222 = 1,888 Free Mint + 334 Paid Mint, two independent pools.
/// - NO PHASES: one switch (mintOpen) opens Free and Paid at the same moment.
///   Neither pool ever blocks the other.
/// - Free Mint: 0 BNB, max 2 per wallet, Binance Agent ID holders only
///   (registry AGENT_ID_REGISTRY, balanceOf > 0, checked on-chain at mint).
///   Free cards are always Standard Issue / Common — no rarity roll.
/// - Paid Mint: PAID_PRICE = 0.0012 BNB per card, max 5 per wallet, open to
///   EVERY wallet from the first moment mint opens — including Binance Agent
///   ID holders, who may mint both Free and Paid. Paid never checks for an
///   Agent ID and never waits for the Free pool.
/// - Paid rarity is rolled inside the mint transaction itself (one call for
///   wallet users and AI agents alike): Common 50% / Rare 32% / Legendary 18%.
///   The roll is pseudo-random from block data (block.prevrandao, timestamp,
///   minter, tokenId) — suitable for this collection's scale; it is not VRF.
/// - Token IDs come from ONE counter in mint order. There is no pre-numbering
///   and no number range per pool.
/// - tokenURI is by card type, not by number: baseURI + one of
///   free.json / paid-common.json / paid-rare.json / paid-legendary.json,
///   chosen from the kind recorded for the token at mint.
/// - Custom name engraving: the token's owner may engrave a name (1–16 bytes)
///   for ENGRAVE_FEE = 0.0005 BNB per engraving, stored on-chain.
/// - Fees are HELD in the contract; the owner collects them with withdraw().
/// - Personal wallets only (msg.sender == tx.origin, contract callers rejected).
/// - mintOpen defaults FALSE: the owner opens mint when ready.
contract AgentCard is ERC721, Ownable {
    uint256 public constant MAX_SUPPLY = 2222;
    uint256 public constant FREE_LIMIT = 1888;
    uint256 public constant PAID_LIMIT = 334;
    uint256 public constant FREE_MAX_PER_WALLET = 2;
    uint256 public constant PAID_MAX_PER_WALLET = 5;
    uint256 public constant PAID_PRICE = 0.0012 ether; // BNB on BNB Smart Chain
    uint256 public constant ENGRAVE_FEE = 0.0005 ether;

    /// @notice Binance Agent ID registry on BNB Chain. Read-only check; the
    /// registry itself is not owned or controlled by this contract.
    address public constant AGENT_ID_REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    // Card kinds recorded per token at mint.
    uint8 public constant KIND_FREE = 0;
    uint8 public constant KIND_PAID_COMMON = 1;
    uint8 public constant KIND_PAID_RARE = 2;
    uint8 public constant KIND_PAID_LEGENDARY = 3;

    string public baseURI;
    bool public mintOpen;
    uint256 public totalMinted;
    uint256 public freeMinted;
    uint256 public paidMinted;
    mapping(address => uint256) public freeMintedByWallet;
    mapping(address => uint256) public paidMintedByWallet;
    mapping(uint256 => uint8) public cardKind;
    mapping(uint256 => string) public engravedName;

    event BaseURISet(string baseURI);
    event CardMinted(address indexed minter, uint256 indexed tokenId, uint8 kind);
    event Engraved(uint256 indexed tokenId, string name);

    constructor(string memory initialBaseURI) ERC721("AgentCard", "ACARD") Ownable(msg.sender) {
        baseURI = initialBaseURI;
    }

    /// @notice True when `wallet` holds at least one Binance Agent ID.
    function hasAgentId(address wallet) public view returns (bool) {
        return IAgentId(AGENT_ID_REGISTRY).balanceOf(wallet) > 0;
    }

    function freeRemaining() public view returns (uint256) {
        return FREE_LIMIT - freeMinted;
    }

    function paidRemaining() public view returns (uint256) {
        return PAID_LIMIT - paidMinted;
    }

    /// @notice Total fee for `qty` Paid cards — agents read this before minting.
    function paidQuote(uint256 qty) public pure returns (uint256) {
        return qty * PAID_PRICE;
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    /// @notice The single mint switch: opening mint opens Free and Paid together.
    function setMintOpen(bool _open) external onlyOwner {
        mintOpen = _open;
    }

    function withdraw() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "empty");
        (bool ok, ) = owner().call{value: bal}("");
        require(ok, "withdraw failed");
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        uint8 kind = cardKind[tokenId];
        string memory file = "free.json";
        if (kind == KIND_PAID_COMMON) file = "paid-common.json";
        else if (kind == KIND_PAID_RARE) file = "paid-rare.json";
        else if (kind == KIND_PAID_LEGENDARY) file = "paid-legendary.json";
        return string(abi.encodePacked(_baseURI(), file));
    }

    /// @notice Free Mint — Binance Agent ID holders only, always Standard Common.
    function freeMint(uint256 qty) external payable {
        require(mintOpen, "mint closed");
        require(msg.sender == tx.origin, "no contracts");
        require(qty > 0, "qty zero");
        require(msg.value == 0, "free mint is free");
        require(hasAgentId(msg.sender), "needs Agent ID");
        require(freeMintedByWallet[msg.sender] + qty <= FREE_MAX_PER_WALLET, "max 2 free per wallet");
        require(freeMinted + qty <= FREE_LIMIT, "free pool sold out");
        require(totalMinted + qty <= MAX_SUPPLY, "supply");
        for (uint256 i = 0; i < qty; i++) {
            totalMinted += 1;
            freeMinted += 1;
            freeMintedByWallet[msg.sender] += 1;
            cardKind[totalMinted] = KIND_FREE;
            _safeMint(msg.sender, totalMinted);
            emit CardMinted(msg.sender, totalMinted, KIND_FREE);
        }
    }

    /// @notice Paid rarity roll: Common 50% / Rare 32% / Legendary 18%.
    function _rollPaidKind(uint256 tokenId) internal view returns (uint8) {
        uint256 r = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.timestamp, msg.sender, tokenId))
        ) % 100;
        if (r < 50) return KIND_PAID_COMMON;
        if (r < 82) return KIND_PAID_RARE;
        return KIND_PAID_LEGENDARY;
    }

    /// @notice Paid Mint — open to every wallet, Agent ID holders included.
    /// No Agent ID check, no Free-pool check, no phase: wallet + Paid pool +
    /// max 5 per wallet + the exact fee are the only gates.
    function paidMint(uint256 qty) external payable {
        require(mintOpen, "mint closed");
        require(msg.sender == tx.origin, "no contracts");
        require(qty > 0, "qty zero");
        require(paidMintedByWallet[msg.sender] + qty <= PAID_MAX_PER_WALLET, "max 5 paid per wallet");
        require(paidMinted + qty <= PAID_LIMIT, "paid pool sold out");
        require(totalMinted + qty <= MAX_SUPPLY, "supply");
        require(msg.value == qty * PAID_PRICE, "wrong fee");
        for (uint256 i = 0; i < qty; i++) {
            totalMinted += 1;
            paidMinted += 1;
            paidMintedByWallet[msg.sender] += 1;
            uint8 kind = _rollPaidKind(totalMinted);
            cardKind[totalMinted] = kind;
            _safeMint(msg.sender, totalMinted);
            emit CardMinted(msg.sender, totalMinted, kind);
        }
    }

    /// @notice Engrave a custom name on a card you own (1–16 bytes).
    /// Costs ENGRAVE_FEE per engraving; re-engraving replaces the name.
    function engrave(uint256 tokenId, string calldata name) external payable {
        require(ownerOf(tokenId) == msg.sender, "not your card");
        require(msg.value == ENGRAVE_FEE, "wrong fee");
        uint256 len = bytes(name).length;
        require(len >= 1 && len <= 16, "name 1-16 chars");
        engravedName[tokenId] = name;
        emit Engraved(tokenId, name);
    }
}
