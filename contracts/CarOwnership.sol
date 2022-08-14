//SPDX-License-Identifier: Unlicense
pragma solidity >=0.4.21 <0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract CarOwnership {

    IERC20 public _token;

    uint32 public car_id = 0;   // Product ID
    uint32 public participant_id = 0;   // Participant ID
    uint32 public owner_id = 0;   // Ownership ID

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
        uint32 carOwner;
        uint256 mfgTimeStamp;
        uint256 reservedAmount;
        uint32 reservedByParticipantId;
    }

    mapping(uint32 => car) public cars;

    struct participant {
        string userName;
        string firstName;
        string lastName;
        string participantType; // there are only two type: "Manufacturer" and "Owner"
        address participantAddress;
    }

    mapping(uint32 => participant) public participants;

    struct ownership {
        uint32 carId;
        uint32 ownerId;
        uint256 trxTimeStamp;
        address carOwner;
    }

    mapping(uint32 => ownership) public ownerships; // ownerships by ownership ID (owner_id)
    mapping(uint32 => uint32[]) public carTrack;  // ownerships by Car ID (car_id) / Movement track for a car

    event TransferOwnership(uint32 carId);

    function addParticipant(string memory _userName, string memory _firstName, string memory _lastName, address _pAdd, string memory _pType) public returns (uint32){
        uint32 userId = participant_id++;
        participants[userId].userName = _userName;
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
        cars[carId].carOwner = _ownerId;
        cars[carId].mfgTimeStamp = block.timestamp;

        return carId;
    }

    modifier onlyOwner(uint32 _carId) {
         require(msg.sender == participants[cars[_carId].carOwner].participantAddress,"");
         _;

    }

    function getCar(uint32 _carId) public view returns (string memory,uint32,uint256,bool){
        return (cars[_carId].serialNumber,
                cars[_carId].carOwner,
                cars[_carId].mfgTimeStamp, 
                cars[_carId].reservedByParticipantId != 0 // is reserved flag
                );
    }

    function reserveCar(uint32 _carId, uint32 _buyerId, uint _amount) public {

        participant memory buyer = participants[_buyerId];
        car memory theCar = cars[_carId];

        require(bytes(theCar.serialNumber).length != 0, "Car does not exist!");
        require(bytes(buyer.userName).length != 0, "Participant does not exist!");
        // Escrow amount cannot be equal to 0
        require(_amount != 0, "Escrow amount cannot be equal to 0.");
        // Car is already reserved
        require(theCar.reservedByParticipantId == 0, "The car is already booked.");

        // Transfer ERC20 token from sender to this contract
        require(_token.transferFrom(msg.sender, address(this), _amount), "Transfer to escrow failed!");

        theCar.reservedByParticipantId = _buyerId;
        theCar.reservedAmount = _amount;
    }

    function confirmReservation(uint32 _sellerId, uint32 _buyerId, uint32 _carId) onlyOwner(_carId) public {
        car memory theCar = cars[_carId];
        participant memory buyer = participants[_buyerId];
        participant memory seller = participants[_sellerId];

        require(theCar.reservedAmount > 0, "Car is not reserved!");

        // Again check buyer address
        require(msg.sender == seller.participantAddress, "Buyer address inconsistent");
        // Transfer ERC20 token from escrow (this) to seller account
        require(_token.transfer(seller.participantAddress, theCar.reservedAmount), "Escrow retrieval failed!");

        uint32 ownership_id = owner_id++;

        ownerships[ownership_id].carId = _carId;
        ownerships[ownership_id].carOwner = buyer.participantAddress;
        ownerships[ownership_id].ownerId = _buyerId;
        ownerships[ownership_id].trxTimeStamp = block.timestamp;
        theCar.carOwner = _buyerId;
        theCar.reservedAmount = 0;
        theCar.reservedByParticipantId = 0;
        carTrack[_carId].push(ownership_id);
        emit TransferOwnership(_carId);
    }

    function cancelResercation(uint32 _carId) public {
        car memory theCar = cars[_carId];
        participant memory buyer = participants[theCar.reservedByParticipantId];

        require(theCar.reservedByParticipantId == 0, "Car is not reserved");
        require(_token.transferFrom(address(this), buyer.participantAddress, theCar.reservedAmount), "Transfer to escrow failed!");
        theCar.reservedAmount = 0;
        theCar.reservedByParticipantId = 0;
    }

    function getProvenance(uint32 _carId) external view returns (uint32[] memory) {

       return carTrack[_carId];
    }

    function getOwnership(uint32 _regId)  public view returns (uint32,uint32,address,uint256) {

        ownership memory r = ownerships[_regId];

        return (r.carId,r.ownerId,r.carOwner,r.trxTimeStamp);
    }

}