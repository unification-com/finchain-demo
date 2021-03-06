pragma solidity >= 0.4.22;

contract Crypto {
    address public owner;
    uint public threshold;
    uint public timeDiff;

    modifier onlyOwner() {
     require (msg.sender == owner,
            "Only owner can call this function.");
      _;
     }

     modifier isAuthorized() {
     require (whiteList[msg.sender] == true,
        "Only authorized addresses can call this function.");
      _;
     }

     //struct to store Stock data
     struct Currency {
         uint256 price;
         uint timestamp;
     }

     //event to emit stock data
     event currencyData(
         address indexed _from,
         string _ticker,
         uint256 _price,
         uint _timestamp,
         bytes32 indexed _tickerHash,
         string _source
     );

     //event shows which stock has a possible arbitrage opportunity at a specified price
     event discrepancy(
         string _ticker,
         address _oracle1,
         uint256 _price1,
         uint _timestamp1,
         string _source1,
         address _oracle2,
         uint256 _price2,
         uint _timestamp2,
         string _source2,
         bytes32 indexed _tickerHash,
         uint _threshold
     );

     event addDataSource(
         address _oracle,
         string _source
     );

     uint public numSources;
     mapping (address => bool) public whiteList; //whitelisted oracle addresses
     address[] public oracleArr; //array of oracle addresses
     mapping (address => string) public sources;
     /*
     Mapping of oracle Addresses to stock arrays
     This allocates an array of currency structs to every oracle address
     */
     mapping(bytes32 => mapping(address => Currency)) currencies;

     constructor (uint _threshold, uint _timeDiff) public {
         owner = msg.sender;
         whiteList[owner] = true;
         threshold = _threshold;
         timeDiff = _timeDiff;
     }

     function updateCurrency(
         string memory _ticker,
         uint256 _price,
         uint256 _timestamp
         )
         public isAuthorized() {

         bytes32 tickerHash = keccak256(abi.encodePacked(_ticker));

         currencies[tickerHash][msg.sender] = Currency({price: _price, timestamp: _timestamp});

         emit currencyData(msg.sender, _ticker, _price, _timestamp, tickerHash, sources[msg.sender]);

         compareCurrencies(_ticker, tickerHash, _timestamp, msg.sender);
     }

     function compareCurrencies(string memory _ticker, bytes32 tickerHash, uint _timestamp, address _o1) public {

         uint p1 = currencies[tickerHash][_o1].price;
         for(uint i = 0; i < numSources; i++) {
             address o2 = oracleArr[i];
             uint p2 = currencies[tickerHash][o2].price;
             uint ts2 = currencies[tickerHash][o2].timestamp;
             uint tsDiff = max(_timestamp, ts2) - min(_timestamp, ts2);

             if(errorMargins(p1, p2) && tsDiff < timeDiff && _o1 != o2) {
                 emit discrepancy(
                     _ticker,
                     _o1,
                     p1,
                     _timestamp,
                     getSource(_o1),
                     o2,
                     p2,
                     ts2,
                     getSource(o2),
                     tickerHash,
                     threshold
                 );
             }
         }
     }

    function errorMargins(uint _p1, uint _p2) public view returns (bool) {
        /*
        This function checks for a significant price difference
        for each stock between sources. The threshold level to emit an event is
        configured in the configureErrorMargins function
        */

        uint temp1 = min(_p1, _p2);

        uint comp1 = _p1 - temp1;
        if ( comp1 >= threshold) return true;
        uint comp2 = _p2 - temp1;
        if ( comp2 >= threshold) return true;

        return false;

    }

     function addSource(address _oracle, string memory _source) public onlyOwner() {
         if(whiteList[_oracle] != true) {
             whiteList[_oracle] = true;
             oracleArr.push(_oracle);
             sources[_oracle] = _source;
             numSources = numSources + 1;
             emit addDataSource(_oracle, _source);
         }
     }

    function setThreshold(uint _threshold) public onlyOwner() {
        require(_threshold > 0, "threshold must be > 0");
        threshold = _threshold;
     }

     function setTimeDiff(uint _timeDiff) public onlyOwner() {
         require(_timeDiff > 0, "timeDiff must be > 0");
         timeDiff = _timeDiff;
     }

     //function to determine the smallest between two values. Used as a way to 
     //find the percent difference between two prices, and to avoid negative values

    function min(uint a, uint b) private pure returns (uint) {
         return a < b ? a : b;
    }

    function max(uint a, uint b) private pure returns (uint) {
         return a > b ? a : b;
    }

    function getSource(address _oracle) public view returns (string memory) {
        return sources[_oracle];
    }

    function getAllOracles() public view returns (address[] memory){
        address[] memory ret = new address[](numSources);
        for (uint i = 0; i < numSources; i++) {
            ret[i] = oracleArr[i];
        }
        return ret;
    }
}