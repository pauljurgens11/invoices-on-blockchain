// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract InvoiceManager {
    enum InvoiceIssuerStatus { Pending, Approved, PaymentReceived, Rejected }
    enum InvoiceRecipientStatus { Pending, Approved, Paid, Overdue, Rejected }

    struct Invoice {
        uint id;
        string issuerName;
        string clientName;
        address issuer;
        address recipient;
        uint amount;
        uint dueDate;
        InvoiceIssuerStatus issuerStatus;
        InvoiceRecipientStatus recipientStatus;
        uint creationDate;
        uint lastModifiedDate;
        string message;
    }

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    uint public invoiceCount;
    mapping(uint => Invoice) public invoices;
    mapping(address => uint[]) public userInvoices;

    event InvoiceCreated(uint id, address issuer, address recipient, uint amount, uint dueDate);
    event InvoiceUpdated(uint id, InvoiceIssuerStatus issuerStatus, InvoiceRecipientStatus recipientStatus);
    
    // Create a new invoice
    function createInvoice(string memory _issuerName, string memory _clientName, address _recipient, uint _amount, uint _dueDate, string memory _message) public {
        require(_recipient != address(0), "Invalid recipient address");
        require(msg.sender != _recipient, "Invoice can't be assigned to yourself");
        require(_dueDate > block.timestamp, "Due date must be in the future");

        invoiceCount++;
        invoices[invoiceCount] = Invoice({
            id: invoiceCount,
            issuerName: _issuerName,
            clientName: _clientName,
            issuer: msg.sender,
            recipient: _recipient,
            amount: _amount,
            dueDate: _dueDate,
            issuerStatus: InvoiceIssuerStatus.Approved,
            recipientStatus: InvoiceRecipientStatus.Pending,
            creationDate: block.timestamp,
            lastModifiedDate: block.timestamp,
            message: _message
        });

        userInvoices[msg.sender].push(invoiceCount);
        userInvoices[_recipient].push(invoiceCount);

        emit InvoiceCreated(invoiceCount, msg.sender, _recipient, _amount, _dueDate);
    }

    // Approve an invoice
    function approveInvoice(uint _id) public {
        Invoice storage invoice = invoices[_id];

        require(msg.sender == invoice.recipient || msg.sender == invoice.issuer, "Only issuer or recipient can approve this invoice.");
        if (msg.sender == invoice.recipient) {
            require(invoice.recipientStatus == InvoiceRecipientStatus.Pending, "Only pending invoices can be approved");
            invoice.recipientStatus = InvoiceRecipientStatus.Approved;
        } else {
            require(invoice.issuerStatus == InvoiceIssuerStatus.Pending, "Only pending invoices can be approved");
            invoice.issuerStatus = InvoiceIssuerStatus.Approved;
        }

        invoice.lastModifiedDate = block.timestamp;
        emit InvoiceUpdated(_id, invoice.issuerStatus, invoice.recipientStatus);
    }

    // Reject an invoice
    function rejectInvoice(uint _id) public {
        Invoice storage invoice = invoices[_id];
        require(msg.sender == invoice.recipient || msg.sender == invoice.issuer, "Only issuer or recipient can approve this invoice.");
        if (msg.sender == invoice.recipient) {
            require(invoice.recipientStatus == InvoiceRecipientStatus.Pending, "Only pending invoices can be approved");
        } else {
            require(invoice.issuerStatus == InvoiceIssuerStatus.Pending, "Only pending invoices can be approved");
        }

        invoice.recipientStatus = InvoiceRecipientStatus.Rejected;
        invoice.issuerStatus = InvoiceIssuerStatus.Rejected;
        invoice.lastModifiedDate = block.timestamp;
        emit InvoiceUpdated(_id, invoice.issuerStatus, invoice.recipientStatus);
    }

    // Modify a rejected invoice
    function modifyInvoice(uint _id, string memory _clientName, uint _amount, uint _dueDate, string memory _message) public {
        Invoice storage invoice = invoices[_id];

        require(msg.sender == invoice.recipient || msg.sender == invoice.issuer, "Only issuer or recipient can approve this invoice.");
        require(_dueDate > block.timestamp, "Due date must be in the future");

        if (msg.sender == invoice.recipient) {
            require(invoice.recipientStatus == InvoiceRecipientStatus.Pending, "Only pending invoices can be approved");
            invoice.recipientStatus = InvoiceRecipientStatus.Approved;
            invoice.issuerStatus = InvoiceIssuerStatus.Pending;
        } else {
            require(invoice.issuerStatus == InvoiceIssuerStatus.Pending, "Only pending invoices can be approved");
            invoice.issuerStatus = InvoiceIssuerStatus.Approved;
            invoice.recipientStatus = InvoiceRecipientStatus.Pending;
        }

        invoice.clientName = _clientName;
        invoice.amount = _amount;
        invoice.dueDate = _dueDate;
        invoice.message = _message;
        invoice.lastModifiedDate = block.timestamp;
        emit InvoiceUpdated(_id, invoice.issuerStatus, invoice.recipientStatus);
    }

    // Pay an invoice
    function payInvoice(uint _id) public payable {
        Invoice storage invoice = invoices[_id];
        require(msg.sender == invoice.recipient, "Only the recipient can pay this invoice");
        require(invoice.recipientStatus == InvoiceRecipientStatus.Approved, "Invoice is not Approved by recipient");
        require(invoice.issuerStatus == InvoiceIssuerStatus.Approved, "Invoice is not Approved by issuer");
        require(msg.value == invoice.amount, "Incorrect payment amount");

        invoice.recipientStatus = InvoiceRecipientStatus.Paid;
        invoice.issuerStatus = InvoiceIssuerStatus.PaymentReceived;
        invoice.lastModifiedDate = block.timestamp;
        payable(invoice.issuer).transfer(msg.value);

        emit InvoiceUpdated(_id, invoice.issuerStatus, invoice.recipientStatus);
    }

    // Check and update overdue invoices
    function checkAndMarkOverdue() public onlyOwner {
        for (uint i = 1; i <= invoiceCount; i++) {
            Invoice storage invoice = invoices[i];
            if (block.timestamp > invoice.dueDate 
                && (invoice.recipientStatus != InvoiceRecipientStatus.Paid 
                || invoice.recipientStatus != InvoiceRecipientStatus.Rejected 
                || invoice.recipientStatus != InvoiceRecipientStatus.Overdue)) {

                invoice.recipientStatus = InvoiceRecipientStatus.Overdue;
                invoice.lastModifiedDate = block.timestamp;
                emit InvoiceUpdated(i, invoice.issuerStatus, invoice.recipientStatus);
            }
        }
    }

    function getMyInvoices() public view returns (uint[] memory) {
        return userInvoices[msg.sender];
    }

    function getUserInvoices(address _user) public view returns (uint[] memory) {
        return userInvoices[_user];
    }

    function getInvoiceById(uint _id) public view returns (Invoice memory) {
        return invoices[_id];
    }
}
