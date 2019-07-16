pragma solidity ^0.4.8;

contract ERC20 {
    uint public totalSupply;

    function balanceOf(address who) public returns (uint);

    function allowance(address owner, address spender) public returns (uint);

    function transfer(address to, uint value) public returns (bool ok);

    function transferFrom(address from, address to, uint value) public returns (bool ok);

    function approve(address spender, uint value) public returns (bool ok);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Mint(address indexed to, uint256 amount);
}


contract Ownable {
    address public owner;
    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        owner = msg.sender;
    }
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) onlyOwner public {
        require(newOwner != address(0));
        owner = newOwner;
    }
}


contract TokenSpender {
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public;
}

contract SafeMath {
    function safeMul(uint a, uint b) internal pure returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function safeDiv(uint a, uint b) internal pure returns (uint) {
        assert(b > 0);
        uint c = a / b;
        assert(a == b * c + a % b);
        return c;
    }

    function safeSub(uint a, uint b) internal pure returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function safeAdd(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        assert(c >= a && c >= b);
        return c;
    }

    function max64(uint64 a, uint64 b) internal pure returns (uint64) {
        return a >= b ? a : b;
    }

    function min64(uint64 a, uint64 b) internal pure returns (uint64) {
        return a < b ? a : b;
    }

    function max256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }


}

contract PullPayment {
    mapping(address => uint) public payments;

    event RefundETH(address to, uint value);
    // store sent amount as credit to be pulled, called by payer
    function asyncSend(address dest, uint amount) internal {
        payments[dest] += amount;
    }

    // withdraw accumulated balance, called by payee
    function withdrawPayments() public {
        address payee = msg.sender;
        uint payment = payments[payee];

        if (payment == 0) {
            revert();
        }

        if (address(this).balance < payment) {
            revert();
        }

        payments[payee] = 0;

        if (!payee.send(payment)) {
            revert();
        }
        emit RefundETH(payee, payment);
    }
}
contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool _paused = false;

    modifier stopInEmergency {
        if (_paused) {
            revert();
        }
        _;
    }

    function paused() public constant returns(bool)
    {
        return _paused;
    }

    /**
     * @dev modifier to allow actions only when the contract IS paused
     */
    modifier whenNotPaused() {
        require(!paused());
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() onlyOwner public {
        require(!_paused);
        _paused = true;
        emit Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() onlyOwner public {
        require(_paused);
        _paused = false;
        emit Unpause();
    }
}

//The interface of the contract to transfer tokens to others
contract MigrationAgent
{
    function migrateFrom(address _from, uint256 _value) public;
}

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

contract Token is Ownable {
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);

    // This generates a public event on the blockchain that will notify clients
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor (
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;                // Give the creator all initial tokens
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
    }

    function getRemainingTokens(address beneficiary) public view onlyOwner returns (uint tokens) {
        return balanceOf[beneficiary];
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balanceOf[_from] >= _value);
        // Check for overflows
        require(balanceOf[_to] + _value >= balanceOf[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        // Subtract from the sender
        balanceOf[_from] -= _value;
        // Add the same to the recipient
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` on behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);     // Check allowance
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public
    returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
    public
    returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough
        balanceOf[msg.sender] -= _value;            // Subtract from the sender
        totalSupply -= _value;                      // Updates totalSupply
        emit Burn(msg.sender, _value);
        return true;
    }

}

contract Crowdsale is SafeMath, PullPayment, Pausable {

    struct Investor {
        uint weiReceived;        // Amount of ETH given
        uint tokensToSent;
    }
    enum ICOType {PREICO, ICO}   // Crowdsale type

    Token public token;          // contract reference
    address public owner;        // contract owner
    ICOType icoType;
    uint public rateTokenPerETH; // Number of tokens per ETH 200000000000
    uint public ETHReceived;     // Number of ETH received
    uint public TokenSentToETH;  // Number of tokens sent to ETH contributors
    uint public startBlock;      // Crowdsale start block
    uint public endBlock;        // Crowdsale end block
    uint public minCap;          // Minimum number of tokens to sell
    uint public maxCap;          // Maximum number of tokens to sell
    bool public maxCapReached;   // Max cap has been reached
    uint public minInvestETH;    // Minimum amount to invest
    bool public crowdsaleClosed; // Is crowdsale still on going

    uint public tokenPrice = 3;  // token's rate

    address public bounty;       // address at which the bounty tokens will be sent
    address public reserve;      // address at which the contingency reserve will be sent
    address public team;         // address at which the team tokens will be sent

    uint public tokens_community;// amount of the community tokens
    uint public tokens_bounty;   // amount of bounties tokens
    uint public tokens_reserve;  // amount of the contingency reserve
    uint public tokens_team;     // amount of the team tokens

    uint public tokenRateLevel1;
    uint public tokenRateLevel2;

    uint public bonusPreICO;
    uint public bonusICOlevel1;
    uint public bonusICOlevel2;
    uint public bonusICOlevel3;
    uint public bonusICOlevel4;

    // when starts stage in hours after start ICO
    uint public durationPreICO;
    uint public durationICOlevel1;
    uint public durationICOlevel2;
    uint public durationICOlevel3;
    uint public durationICOlevel4;



    mapping(address => Investor) public investors; //investorsETH indexed by their ETH address

    modifier onlyBy(address a){
        if (msg.sender != a) revert();
        _;
    }

    modifier minCapNotReached() {
        if ((now < endBlock) || TokenSentToETH >= minCap) revert();
        _;
    }

    modifier respectTimeFrame() {
        if ((now < startBlock) || (now > endBlock)) revert();
        _;
    }

    /*
    * Events
    */
    event ReceivedETH(address addr, uint value);
    event Logs(address indexed from, uint amount, string value);
    event Referral(address indexed referrer, uint256 amount);
    event Refunded(address indexed beneficiary, uint256 weiAmount);
    /*
    *	Constructor
    */
    function Crowdsale() public onlyOwner {

        owner = msg.sender;

        tokenRateLevel1 = 3;
        tokenRateLevel2 = 4;

        token = Token(0x9ba17Df4377Ae100dAD84b6cCfC6fEab6cDA02B7);
        team = 0x5EDa11efC0AE41Df36ef9770E21C02D54D40FEB5;
        reserve = 0x5EDa11efC0AE41Df36ef9770E21C02D54D40FEB5;
        bounty = 0x5EDa11efC0AE41Df36ef9770E21C02D54D40FEB5;
        TokenSentToETH = 0;
        minInvestETH = 750 finney;
        tokenPrice = tokenRateLevel1;
        startBlock = now;
        endBlock = now + 3 hours; // should wait for the call of the function start
        rateTokenPerETH = 28514; //default rate, will be updated by cron
        maxCap = safeMul(safeDiv(13000000, rateTokenPerETH), 100000000000000000000) ; //value $ by rate
        minCap = safeMul(safeDiv(1000000, rateTokenPerETH), 10000000000000000000) ; //value $ by rate
        tokens_bounty = 100;
        tokens_community = 100;
        tokens_reserve = 100;
        tokens_team = 100;

        bonusPreICO = 50;
        bonusICOlevel1 = 30;
        bonusICOlevel2 = 20;
        bonusICOlevel3 = 10;
        bonusICOlevel4 = 0;

        durationPreICO = 1 hours;
        durationICOlevel1 =  90 minutes;
        durationICOlevel2 = 120 minutes;
        durationICOlevel3 = 150 minutes;
        durationICOlevel4 = 180 minutes;
    }

    //Returns the name of the current round. Constant
    function ICOSaleType() public constant returns (string) {
        if (endBlock == 0) {
            return "NOT_STARTED";
        } else if (now < safeAdd(startBlock, durationPreICO)) {
            return "PREICO";
        } else if (now < safeAdd(startBlock, durationICOlevel1)) {
            return "ICO_LEVEL_ONE";
        } else if (now < safeAdd(startBlock, durationICOlevel2)) {
            return "ICO_LEVEL_TWO";
        } else if (now < safeAdd(startBlock, durationICOlevel3)) {
            return "ICO_LEVEL_THREE";
        } else if (now < safeAdd(startBlock, durationICOlevel4)) {
            return "ICO_LEVEL_FOUR";
        } else {
            return "ICO_ENDED";
        }
    }

    /*
    * How much wei received from investor
    */
    function getWeireceived(address beneficiary) public view  returns (uint weiReceived) {
        Investor storage investor = investors[beneficiary];
        return investor.weiReceived;
    }

    /*
    * How much tokens will be send to investor
    */
    function getTokensToSend(address beneficiary) public view  returns (uint tokenSent) {
        Investor storage investor = investors[beneficiary];
        return investor.tokensToSent;
    }

    /*
    * Change rate on different steps
    */
    function changeTokenRate() internal returns (uint tokenRate) {
        if (icoType == ICOType.PREICO) {
            tokenPrice = tokenRateLevel1;
        } else {
            tokenPrice = tokenRateLevel2;
        }
        return tokenPrice;
    }

    /*
    * Get tokens price
    */
    function getTokenPrice() public view returns (uint tokenRate) {
        return tokenPrice;
    }

    /*
    * Calculate amount of tokens include bonus by weiReceived from investor
    */
    function calculateTokens(uint weiReceived) public view returns (uint tokenSent) {
        uint tokenRate = getTokenPrice();
        uint tokensToSend = bonus(safeDiv(safeMul(weiReceived, rateTokenPerETH) / (1 ether), tokenRate));
        return tokensToSend;
    }

    /*
    * Calculate amount of tokens without bonus by weiReceived from investor
    */
    function calculateTokensWithoutBonus(uint weiReceived) public view returns (uint tokenSent) {
        uint tokenRate = getTokenPrice();
        uint tokensToSend = safeDiv(safeMul(weiReceived, rateTokenPerETH) / (1 ether), tokenRate);
        return tokensToSend;
    }

    /*
     * When sending eth, if all conditions are okay, send tokens to the address
     */
    function() public payable {
        if (now > endBlock) revert();
        receiveETH(msg.sender);
    }

    /*
     * To call to start the PreICO
     */
    function startPreICO(uint256 startTime) public onlyBy(owner) {
        require(!crowdsaleClosed);
        //StartDate is correct
        require(now <= startTime);
        icoType = ICOType.PREICO;
        startBlock = startTime;
        endBlock = now + 2*30 days; //2 months
    }

    /*
    * To call to start the ICO
    */
    function startICO() public onlyBy(owner) {
        icoType = ICOType.ICO;
    }

    /*
    *	Receives a donation in ETH
    */
    function receiveETH(address beneficiary) internal stopInEmergency respectTimeFrame {
        if (msg.value < minInvestETH) revert();
        if (endBlock == 0) revert(); // if ico is not started
        if (now > safeAdd(startBlock, durationICOlevel4)) revert(); //if ico is ended
        tokenPrice = getTokenPrice();

        //don't accept funding under a predefined threshold
        uint tokensToSend = bonus(safeDiv(safeMul(msg.value, rateTokenPerETH) / (1 ether), tokenPrice));
        //compute the number of tokens to send

        Investor storage investor = investors[beneficiary];
        // Do the Token transfer right now
        investor.tokensToSent = safeAdd(investor.tokensToSent, tokensToSend);
        investor.weiReceived = safeAdd(investor.weiReceived, msg.value);
        // Update the total wei collected during the crowdfunding for this investor
        ETHReceived = safeAdd(ETHReceived, msg.value);
        // Update the total wei collected during the crowdfunding
        TokenSentToETH = safeAdd(TokenSentToETH, tokensToSend);

        emitToken(tokensToSend);
        // compute the variable part
        emit ReceivedETH(beneficiary, ETHReceived);
        // send the corresponding contribution event
    }

    /*
     *Compute the variable part
     */
    function emitToken(uint amount) internal {
        tokens_community = safeAdd(tokens_community, safeDiv(amount, 60));
        tokens_bounty = safeAdd(tokens_bounty, safeDiv(amount, 3));
        tokens_team = safeAdd(tokens_team, safeDiv(amount, 15));
        tokens_reserve = safeAdd(tokens_reserve, safeDiv(amount, 22));
        emit Logs(msg.sender, amount, "emitToken");
    }

    /*
     *Compute the Token bonus according to the investment period
     */
    function bonus(uint amount) internal constant returns (uint) {
        if (endBlock == 0) { //not started
            return amount;
        } else if (now < safeAdd(startBlock, durationPreICO)) { //PRE_ICO
            return (safeAdd(amount, safeDiv(safeMul(amount, bonusPreICO), 100)));
        } else if (now < safeAdd(startBlock, durationICOlevel1)) { // 1st stage
            return (safeAdd(amount, safeDiv(safeMul(amount, bonusICOlevel1), 100)));
        } else if (now < safeAdd(startBlock, durationICOlevel2)) { // 2nd stage
            return (safeAdd(amount, safeDiv(safeMul(amount, bonusICOlevel2), 100)));
        } else if (now < safeAdd(startBlock, durationICOlevel3)) { // 3rd stage
            return (safeAdd(amount, safeDiv(safeMul(amount, bonusICOlevel3), 100)));
        } else if (now < safeAdd(startBlock, durationICOlevel4)) { // 4th stage
            return amount;
        } else { //end
            return amount;
        }
    }

    /*
    * function to send ico's balance to owner, execute can only owner of ico
    */
    function withdraw() public onlyOwner {
        owner.transfer(address(this).balance);
    }

    /*
    * Update the rate Token per ETH, computed externally by using the ETHBTC index on kraken every N min
    */
    function setTokenPerETHStatic(uint rate) public onlyOwner{
        rateTokenPerETH = rate;
    }

}
