// SPDX-License-Identifier: MIT
// monmo_2021_solidity_tests
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


/**
 * @title CalvaToken
 * @notice Implementa el token ERC20 como moneda de cambio.
 */
contract CalvaToken is ERC20, ERC20Burnable, Pausable, Ownable, ERC20Permit {
    constructor() ERC20("CalvaToken", "CLV") ERC20Permit("CalvaToken") {
        //se envía 1m de token iniciales a la cuenta del creador del contrato.
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}

/**
 * @title CalvaToken
 * @notice Implementa el token ERC20 como moneda de cambio.
 */
contract Pakos is ERC721, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Pakos", "PAKO") {}
    
    event NewPakos(uint pakoId, string name, uint dna);
    
    uint dnaDigits = 16;
    uint dnaModulus = 10 ** dnaDigits;
    uint cooldownTime = 1 days;
    
    struct Pako {
        string name;
        uint dna;
        uint32 readyTime;
        uint16 winCount;
        uint16 lossCount;
    }
    
    Pako[] public pakos;
    
    mapping (uint => address) public pakoToOwner;
    mapping ( address => uint) ownerPakoCount;
    
    function _createPako(string memory _name, uint _dna) private {
        pakos.push(Pako(_name, _dna, 1, uint16(block.timestamp + cooldownTime), 0));
        uint id = pakos.length -1;
        pakoToOwner[id] = msg.sender;
        ownerPakoCount[msg.sender] = ownerPakoCount[msg.sender]++;
        emit NewPakos(id, _name, _dna);
    }
    
    
  function _generateRandomDna(string memory _str) private view returns (uint) {
    uint rand = uint(keccak256(abi.encodePacked(_str)));
    return rand % dnaModulus;
  }

  function createRandomPako(string memory _name) public {
    require(ownerPakoCount[msg.sender] == 0);
    uint randDna = _generateRandomDna(_name);
    randDna = randDna - randDna % 100;
    _createPako(_name, randDna);
  }

    function safeMint(address to) public onlyOwner {
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}

/**
 * @title Classifieds
 * @notice Implementa los anuncios. El mercado se regirá por los CalvaToken generados
 * como moneda de cambio y un token ERC721 (Pakos) que representa la propiedad
 * de los artículos que se comercializan.
 * 
 * Solo los anuncios para vender artículos son implementados. La tokenizaci´ón
 * del artículo es responsabilidad del token ERC721 que debe codificar los 
 * detalles del artículo.
 */
contract Classifieds {
    event TradeStatusChange(uint256 ad, bytes32 status);

    IERC20 currencyToken;
    IERC721 itemToken;

    struct Trade {
        address poster;
        uint256 item;
        uint256 price;
        bytes32 status; // Open, Executed, Cancelled
    }

    mapping(uint256 => Trade) public trades;

    uint256 tradeCounter;

   constructor (address _currencyTokenAddress, address _itemTokenAddress)
        public payable
    {
        currencyToken = IERC20(_currencyTokenAddress);
        itemToken = IERC721(_itemTokenAddress);
        tradeCounter = 0;
    }

    /**
     * @dev Returns the details for a trade.
     * @param _trade The id for the trade.
     */
    function getTrade(uint256 _trade)
        public
        virtual
        view
        returns(address, uint256, uint256, bytes32)
    {
        Trade memory trade = trades[_trade];
        return (trade.poster, trade.item, trade.price, trade.status);
    }

    /**
     * @dev Opens a new trade. Puts _item in escrow.
     * @param _item The id for the item to trade.
     * @param _price The amount of currency for which to trade the item.
     */
    function openTrade(uint256 _item, uint256 _price)
        public
        virtual
    {
        itemToken.transferFrom(msg.sender, address(this), _item);
        trades[tradeCounter] = Trade({
            poster: msg.sender,
            item: _item,
            price: _price,
            status: "Open"
        });
        tradeCounter += 1;
        emit TradeStatusChange(tradeCounter - 1, "Open");
    }

    /**
     * @dev Executes a trade. Must have approved this contract to transfer the
     * amount of currency specified to the poster. Transfers ownership of the
     * item to the filler.
     * @param _trade The id of an existing trade
     */
    function executeTrade(uint256 _trade)
        public
        virtual
    {
        Trade memory trade = trades[_trade];
        require(trade.status == "Open", "Trade is not Open.");
        currencyToken.transferFrom(msg.sender, trade.poster, trade.price);
        itemToken.transferFrom(address(this), msg.sender, trade.item);
        trades[_trade].status = "Executed";
        emit TradeStatusChange(_trade, "Executed");
    }

    /**
     * @dev Cancels a trade by the poster.
     * @param _trade The trade to be cancelled.
     */
    function cancelTrade(uint256 _trade)
        public
        virtual
    {
        Trade memory trade = trades[_trade];
        require(
            msg.sender == trade.poster,
            "Trade can be cancelled only by poster."
        );
        require(trade.status == "Open", "Trade is not Open.");
        itemToken.transferFrom(address(this), trade.poster, trade.item);
        trades[_trade].status = "Cancelled";
        emit TradeStatusChange(_trade, "Cancelled");
    }
}