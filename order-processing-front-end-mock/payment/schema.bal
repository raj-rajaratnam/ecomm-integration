public type Payment record {
    string amount,
    string totalAmount,
    string currency,
    string invoiceId,
    string settlementId,
    string itemIds,
    json additionalProperties,
};