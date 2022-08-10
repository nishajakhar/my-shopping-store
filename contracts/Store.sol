// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract Store {
    string public storeName;
    address public merchant; 
    bool public isSaleOn = false;
    uint public discountPercentage = 10;
    uint private totalSales;
    uint private totalItemsSold;
    uint private discountsGiven;

    event OrderPlaced(uint orderId, uint amount);
    event OrderCancelled(uint orderId, uint amount);
    event SaleStarted(uint percentage);
    event SaleEnded();

    constructor(string memory _storeName) {
        merchant = msg.sender;
        storeName = _storeName;
    }

    struct Item {
        uint itemId;
        string name;
        string itemDetailsURI;
        uint price;
        uint availableQty;
    }
    Item[] public items;

    struct Order {
        uint orderId;
        uint[] itemId;
        uint[] qty;
        uint grossTotal;
        uint discount;
        uint netTotal;
        uint orderCreatedTimestamp;
        Status shippingStatus;
        address placedBy;
    }

    enum Status {
        Accepted,
        Dispatched,
        Delivered,
        Cancelled
    }

    // An array of 'Order' structs
    Order[] public orders;

    mapping(address => Order[]) private customerOrders;
    mapping(address => string) private shippingAddress;
    mapping(uint => string) private orderShipping;

    modifier onlyMerchant() {
        require(msg.sender == merchant);
        _;
    }

    /* 
        Function Name : placeOrder
        Function Description : for customers to place an order with paying in ethers.
        ---------------------------------------------------------------------------------------
        Inputs : 
            - uint[] _items : Array of itemsId to buy
            - uint[] _qty : Array of quantities. It'll correspond exactly with items parameter. 
        --------------------------------------------------------------------------------------------
        Return :
            - uint : an orderId
        ------------------------------------------------------------------------------------------
        Constraints :
            - Mentioned quantity of each item should be available in inventory
            - Amount sent should be equal or more than total cost of all items
    */
    function placeOrder(uint[] memory _items, uint[] memory _qty) public payable returns (uint) {
        uint totalQty;
        uint sum;
        for(uint i=0;i<_items.length;i++){
            totalQty += _qty[i];
            sum += items[_items[i]].price * _qty[i];
            require(items[_items[i]].availableQty >= _qty[i], "Required Quantity Unavailable");
        }
        // uint sum = calculateTotal(uint[] _items, uint[] _qty);
        require(msg.value >= sum, "Insufficent Balance to place order");

        uint discount;
        uint netTotal = sum;
        uint orderId = orders.length + 1;
        if(isSaleOn){
            discount = discountPercentage * sum / 100;
            netTotal = sum - discount;
        }
        Order memory newOrder = Order(orderId, _items, _qty, sum, discount, netTotal, block.timestamp, Status.Accepted, msg.sender);
        orders.push(newOrder);
        orderShipping[orderId] = shippingAddress[msg.sender];
        
        updateItemQuantity(_items, _qty, 0);
        totalSales += netTotal;
        totalItemsSold += totalQty;
        discountsGiven += discount;
        customerOrders[msg.sender].push(newOrder);
        return orderId;
    }

    /* 
        Function Name : cancelOrder
        Function Description : for customers to cancel an order and get their refund back.
        -----------------------------------------------------------------------------------------
        Inputs : 
            - uint _orderId : Id of order to cancel
        ------------------------------------------------------------------------------------------
        Return :
            - bool : status of cancellation
        ------------------------------------------------------------------------------------------
        Constraints :
            - User has be same who placed the order
            - Order Status before dispatched will only be allowed to cancel
            - 
    */
    function cancelOrder(uint _orderId) public {
        require(msg.sender == orders[_orderId].placedBy, "Cannot Be cancelled by another user");
        require(orders[_orderId].shippingStatus < Status.Dispatched, "Cannot Be cancelled after Shipment dispatch");

        Order storage order = orders[_orderId];

        order.shippingStatus = Status.Cancelled;
        updateItemQuantity(order.itemId, order.qty, 1);
        totalSales -= order.netTotal;
        // totalItemsSold -= totalQty; //TODO: When cancelling how to get total qty of products
        discountsGiven -= order.discount;

        payable(msg.sender).call{value : order.netTotal}("");
    }

    /* 
        Function Name : withdrawFunds
        Function Description : for owner of store to withdraw funds from contract to his own address.
        ---------------------------------------------------------------------------------------------
        Inputs : No Inputs
        ---------------------------------------------------------------------------------------------
        Return : Returns Nothing
        ---------------------------------------------------------------------------------------------
        Constraints :
            - Only owner of contract can call this
    */
    function withdrawFunds() external onlyMerchant{
        payable(merchant).call{value : address(this).balance}("");
    }

    /* 
        Function Name : getStatistics
        Function Description : to get statistics of the store
        ---------------------------------------------------------------------------------------
        Inputs : No Inputs
        ----------------------------------------------------------------------------------------
        Return :
            - uint : total items sold till now
            - uint : total sales of the store till now
            - uint : total discounts given till now
        ----------------------------------------------------------------------------------------
        Constraints :
            - Only owner of contract can get these statistics
    */
     function getStatistics() external view onlyMerchant returns (uint, uint, uint){
        return (totalItemsSold, totalSales, discountsGiven);
    }

    /* 
        Function Name : getAllYourOrders
        Function Description : to get details of all order of a particular user(address)
        ---------------------------------------------------------------------------------------
        Inputs : No Inputs
        ----------------------------------------------------------------------------------------
        Return :
            - Order[] : Arrays of Order Struct Type
        ----------------------------------------------------------------------------------------
        Constraints : No Constraints
    */
    function getAllYourOrders() public view returns (Order[] memory){
        return customerOrders[msg.sender];
    }

    /* 
        Function Name : calculateTotal
        Function Description : any user can find out total amount required to pay
                               for the supplied items with quantity
        ---------------------------------------------------------------------------------------
        Inputs : 
            - uint[] _items : Array of itemsId
            - uint[] _qty : Array of quantities. It'll correspond exactly with items parameter. 
        ----------------------------------------------------------------------------------------
        Return :
            - uint : total cost required to pay in wei
        ----------------------------------------------------------------------------------------
        Constraints :
            - Items array and quantity array should be of same length
    */
    function calculateTotal(uint[] memory _items, uint[] memory _qty) public view returns (uint) {
        require(_items.length == _qty.length);
        uint sum;
        for(uint i=0;i<_items.length;i++){
            sum += items[_items[i]].price * _qty[i];
        }
        return sum;
    }

    /* 
        Function Name : updateItemQuantity
        Function Description : Used to update inventory of items. While order placing it will 
                               decrease quantity and while cancelling an order it will 
                               increase the quantity
        ---------------------------------------------------------------------------------------
        Inputs : 
            - uint[] _items : Array of itemsId
            - uint[] _qty : Array of quantities. It'll correspond exactly with items parameter. 
            - uint _type : an integer to denote whether to increase the quantity or decrease
        ----------------------------------------------------------------------------------------
        Return : 
            - bool : status of inventory update
        ----------------------------------------------------------------------------------------
        Constraints :
            - internal : this function can only be called by other functions of this contract 
                         or child contract. User cannot call this function directly
    */
    function updateItemQuantity(uint[] memory _items, uint[] memory _qty, uint _type) internal {
        for(uint i=0;i<_items.length;i++){
            if(_type == 0) items[i].availableQty = items[i].availableQty - _qty[i];
            else items[i].availableQty = items[i].availableQty + _qty[i];
        }
    }

    /* 
        Function Name : addItem
        Function Description : to add new item to the inventory
        ---------------------------------------------------------------------------------------
        Inputs : 
            - uint _name : name of item
            - uint _qty :Quantity of item
            - uint _itemDetailsURI : IPFS URI where details of this item are uploaded 
            - uint _price : price of item in wei
        ----------------------------------------------------------------------------------------
        Return : Returns Nothing
        ----------------------------------------------------------------------------------------
        Constraints :
            - Owner of contract can only call this function
    */
    function addItem(string memory _name, uint _qty, string memory _itemDetailsURI, uint _price) public onlyMerchant {
        items.push(Item(items.length + 1, _name, _itemDetailsURI, _price, _qty));
    }

    /* 
        Function Name : updatePrice
        Function Description : to update price of a item
        ---------------------------------------------------------------------------------------
        Inputs : 
            - uint _itemId : id of item
            - uint _price : price of item in wei
        ----------------------------------------------------------------------------------------
        Return : Returns Nothing
        ----------------------------------------------------------------------------------------
        Constraints :
            - Owner of contract can only call this function
    */
    function updatePrice(uint _itemId, uint _price) public onlyMerchant {
        Item storage item = items[_itemId];
        item.price = _price;
    }

    /* 
        Function Name : updateSaleSatus
        Function Description : start or end the sale
        ---------------------------------------------------------------------------------------
        Inputs : No Inputs
        ----------------------------------------------------------------------------------------
        Return : Returns Nothing
        ----------------------------------------------------------------------------------------
        Constraints :
            - Owner of contract can only call this function
    */
    function updateSaleSatus() public onlyMerchant {
        isSaleOn = !(isSaleOn);
    }

    /* 
        Function Name : updateSalePercentage
        Function Description : updates the discount percentage  to be given during the sale period
        ---------------------------------------------------------------------------------------
        Inputs : No Inputs
        ----------------------------------------------------------------------------------------
        Return : Returns Nothing
        ----------------------------------------------------------------------------------------
        Constraints :
            - Owner of contract can only call this function
    */
    function updateSalePercentage(uint _discountPercentage) public onlyMerchant {
        discountPercentage = _discountPercentage;
    }

    /* 
        Function Name : increaseInventory
        Function Description : to increase the item in inventory
        ---------------------------------------------------------------------------------------
        Inputs : 
            - uint _itemId : Id of item to update
            - uint _qty :Quantity of item
        ----------------------------------------------------------------------------------------
        Return : Returns Nothing
        ----------------------------------------------------------------------------------------
        Constraints :
            - Owner of contract can only call this function
    */
    function increaseInventory(uint _itemId, uint _qty) internal onlyMerchant {
        items[_itemId].availableQty += _qty;
    }

    /* 
        Function Name : decreaseInventory
        Function Description : to decrease the item in inventory
        ---------------------------------------------------------------------------------------
        Inputs : 
            - uint _itemId : Id of item to update
            - uint _qty : Quantity of item to decrease
        ----------------------------------------------------------------------------------------
        Return : Returns Nothing
        ----------------------------------------------------------------------------------------
        Constraints :
            - Owner of contract can only call this function
    */
    function decreaseInventory(uint _itemId, uint _qty) public onlyMerchant {
        if(items[_itemId].availableQty - _qty < 0) items[_itemId].availableQty = 0;
        else items[_itemId].availableQty -=  _qty;
    }

    /* 
        Function Name : updateStatus
        Function Description : to update the status of the order
        ---------------------------------------------------------------------------------------
        Inputs : 
            - uint _orderId : Id of the order to update status
            - Status _status : status id
        ----------------------------------------------------------------------------------------
        Return : Returns Nothing
        ----------------------------------------------------------------------------------------
        Constraints :
            - Owner of contract can only call this function
            - Order status cannot be updated if its in cancelled or delivered state
    */
     function updateStatus(uint _orderId, Status _status) public onlyMerchant {
        require(orders[_orderId].shippingStatus < 2, "Cant update status of completed/cancelled order");
        orders[_orderId].shippingStatus = _status;
    }

    /* 
        Function Name : updateShippingAddress
        Function Description : to update the shipping address of a user
        ---------------------------------------------------------------------------------------
        Inputs : 
            - string : address
        ----------------------------------------------------------------------------------------
        Return : Returns Nothing
        ----------------------------------------------------------------------------------------
        Constraints : No Constraints
    */
     function updateShippingAddress(string memory _address) public {
        shippingAddress[msg.sender] = _address;
    }

    /* 
        Function Name : getShippingAddress
        Function Description : to get the shipping address mapped to an address
        ---------------------------------------------------------------------------------------
        Inputs : No inputs
        ----------------------------------------------------------------------------------------
        Return : 
            - string : shipping address
        ----------------------------------------------------------------------------------------
        Constraints : No Constraints
    */
     function getShippingAddress() public view returns (string memory){
        return shippingAddress[msg.sender];
    }

     /* 
        Function Name : getShippingAddress
        Function Description : to get the shipping address of an order
        ---------------------------------------------------------------------------------------
        Inputs :
            - uint _orderId : Id of order
        ----------------------------------------------------------------------------------------
        Return : 
            - string : shipping address
        ----------------------------------------------------------------------------------------
        Constraints :
            - Only Owner of contract can call this function
    */
     function getOrderShippingAddress(uint _orderId) public view onlyMerchant returns (string memory){
        return orderShipping[_orderId];
    }

    /* 
        Function Name : getItemDetail
        Function Description : to get details of an item
        ---------------------------------------------------------------------------------------
        Inputs : 
            - uint _itemId : Id of the item
        ----------------------------------------------------------------------------------------
        Return : 
            - Item: returns whole item object
        ----------------------------------------------------------------------------------------
        Constraints : No Constraints
    */
    function getItemDetail(uint _itemId) public view returns (Item memory) {
        return items[_itemId];
    }

    /* 
        Function Name : getOrderDetail
        Function Description : to get details of an order
        ---------------------------------------------------------------------------------------
        Inputs : 
            - uint _orderId : Id of the order
        ----------------------------------------------------------------------------------------
        Return : 
            - Item: returns whole order object
        ----------------------------------------------------------------------------------------
        Constraints : No Constraints
    */
    function getOrderDetail(uint _orderId) public view returns (Order memory) {
        return orders[_orderId];
    }

}