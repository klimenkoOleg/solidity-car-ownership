pragma solidity >=0.4.21 <0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract CarOwnership {

    IERC20 public _token;

    uint32 public car_id = 0;   // Product ID
    uint32 public participant_id = 0;   // Participant ID
    // uint32 public owner_id = 0;   // Ownership ID

    uint deposit_count;


    constructor(address ERC20Address) {
        deposit_count = 0;
        _token = IERC20(ERC20Address);
    }

    struct car {
        string makeName; // Toyota, BMW, etc.
        string modelName;
        string bodyStyle;
        string serialNumber;
        address carOwner;
        uint32 mfgTimeStamp;
        uint256 reservedAmount;
        uint32 reservedByParticipantId;
    }

    mapping(uint32 => car) public cars;

    struct participant {
        string idNumber; // passport ID, SSN, etc.
        string firstName;
        string lastName;
        string participantType; // there are only two type: "Manufacturer" and "Owner"
        address participantAddress;
    }

    mapping(uint32 => participant) public participants;

    struct ownership {
        uint32 carId;
        uint32 ownerId;
        uint32 trxTimeStamp;
        address carOwner;
    }

    mapping(uint32 => ownership) public ownerships; // ownerships by ownership ID (owner_id)
    mapping(uint32 => uint32[]) public carTrack;  // ownerships by Car ID (car_id) / Movement track for a car

    event TransferOwnership(uint32 carId);

    function addParticipant(string memory _idNumber, string memory _firstName, string memory _lastName, address _pAdd) public returns (uint32){
        uint32 userId = participant_id++;
        participants[userId].userName = _name;
        participants[userId].firstName = _firstName;
        participants[userId].lastName = _lastName;
        participants[userId].participantAddress = _pAdd;
        participants[userId].participantType = _pType;  

        return userId;
    }

    function getParticipant(uint32 _participant_id) public view returns (string memory,string memory,string memory,address,string memory) {
        return (participants[_participant_id].userName,
                participants[_participant_id].firstName,
                participants[_participant_id].lastName,
                participants[_participant_id].participantAddress,
                participants[_participant_id].participantType);
    }

    function addCar(uint32 _ownerId,
                        string memory _makeName,
                        string memory _modelName,
                        string memory _bodyStyle,
                        string memory _serialNumber) public returns (uint32) {
        if(keccak256(abi.encodePacked(participants[_ownerId].participantType)) != keccak256("Manufacturer")) {
            return 0;
        }

        uint32 carId = car_id++;

        cars[carId].makeName = _makeName;
        cars[carId].modelName = _modelName;
        cars[carId].bodyStyle = _bodyStyle;
        cars[carId].serialNumber = _serialNumber;
        cars[carId].carOwner = participants[_ownerId].participantAddress;
        cars[carId].mfgTimeStamp = uint32(now);

        return carId;
    }

    modifier onlyOwner(uint32 _carId) {
         require(msg.sender == cars[_carId].carOwner,"");
         _;

    }

    function getCar(uint32 _carId) public view returns (string memory,string memory,string memory,string memory,address,uint32){
        return (cars[_carId].makeName,
                cars[_carId].modelName,
                cars[_carId].bodyStyle,
                cars[_carId].serialNumber,
                cars[_carId].carOwner,
                cars[_carId].mfgTimeStamp);
    }

    function reserveCar(bytes32 _carId, uint32 _buyerId, uint amount) public {

        participant memory buyer = participants[_buyerId];
        theCar = cars[_carId];

        require(bytes(theCar.serialNumber).length != 0, "Car does not exist!");
        require(bytes(buyer.userName).length != 0, "Participant does not exist!");

        // Escrow amount cannot be equal to 0
        require(amount != 0, "Escrow amount cannot be equal to 0.");
        // Transfer ERC20 token from sender to this contract
        require(_token.transferFrom(msg.sender, address(this), amount), "Transfer to escrow failed!");
        // Car is already reserved
        require(theCar.reservedBy == address(0), "The car is already booked.");

        theCar.reservedByParticipantId = _buyerId;
        theCar.reservedAmount = amount;
    }

    function confirmReservation(uint32 _sellerId, uint32 _buyerId, uint32 _carId) onlyOwner(_carId) public {
        car memory theCar = cars[_carId];
        participant memory buyer = participants[_buyerId];
        participant memory seller = participants[_sellerId];

        require(theCar.reservedAmount > 0, "Car is not reserved!");
        
        // Escrow amount cannot be equal to 0
        require(amount != 0, "Escrow amount cannot be equal to 0.");
        // Again check buyer address
        require(msg.sender == seller.participantAddress, "Buyer address inconsistent");
        // Transfer ERC20 token from sender to this seller
        require(_token.transfer(msg.sender, seller.participantAddress), "Escrow retrieval failed!");

        uint32 ownership_id = owner_id++;

        ownerships[ownership_id].carId = _carId;
        ownerships[ownership_id].carOwner = buyer.participantAddress;
        ownerships[ownership_id].ownerId = _buyerId;
        ownerships[ownership_id].trxTimeStamp = uint32(now);
        theCar.carOwner = _buyerId.participantAddress;
        theCar.reservedAmount = 0;
        theCar.reservedByParticipantId = 0;
        carTrack[_carId].push(ownership_id);
        emit TransferOwnership(_carId);
    }

    function cancelResercation(bytes32 _carId) public {
        theCar = cars[_carId];
        participant memory buyer = participants[theCar.reservedByParticipantId];

        require(participant.participantAddress != address(0), "Car is not reserved");
        require(_token.transferFrom(address(this), buyer.participantAddress, theCar.reservedAmount), "Transfer to escrow failed!");
        theCar.reservedAmount = 0;
        theCar.reservedByParticipantId = 0;
    }

    function getProvenance(uint32 _carId) external view returns (uint32[] memory) {

       return carTrack[_carId];
    }

    function getOwnership(uint32 _regId)  public view returns (uint32,uint32,address,uint32) {

        ownership memory r = ownerships[_regId];

        return (r.carId,r.ownerId,r.carOwner,r.trxTimeStamp);
    }

}