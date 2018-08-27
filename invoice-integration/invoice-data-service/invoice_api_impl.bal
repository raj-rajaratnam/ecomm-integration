import ballerina/io;
import ballerina/http;
import ballerina/config;

endpoint mysql:Client invoiceDB {
    host: config:getAsString("invoice.db.host"),
    port: config:getAsInt("invoice.db.port"),
    name: config:getAsString("invoice.db.name"),
    username: config:getAsString("invoice.db.username"),
    password: config:getAsString("invoice.db.password"),
    poolOptions: { maximumPoolSize: 5 },
    dbOptions: { useSSL: false, serverTimezone:"UTC" }
};

public function addInvoices (http:Request req, Invoices invoices)
                    returns http:Response {

    http:Response res = new;

    int numberOfInvoices = lengthof invoices.invoices;

    int numberOfRecordsInserted;
    error dbError;
    transaction with retries = 4, oncommit = onCommitFunction,
    onabort = onAbortFunction {

        string sqlString =
        "INSERT INTO invoice_request(ORDER_NO,INVOICE_ID,SETTLEMENT_ID,COUNTRY_CODE,
            PROCESS_FLAG,ERROR_MESSAGE,RETRY_COUNT,ITEM_IDS,TRACKING_NUMBER,REQUEST) VALUES (?,?,?,?,?,?,?,?,?,?)";

        foreach inv in invoices.invoices {
            int|error result = invoiceDB->update(sqlString, inv.orderNo, inv.invoiceId, inv.settlementId, inv.countryCode,
                inv.processFlag, inv.errorMessage, inv.retryCount, inv.itemIds, inv.trackingNumber, inv.request);

            match result {
                int c => {numberOfRecordsInserted += c;}
                error err => { dbError = err; retry;}
            }
        }

        io:println(numberOfInvoices);
        io:println(numberOfRecordsInserted);

        if (numberOfRecordsInserted != numberOfInvoices) {
            abort;
        }

    } onretry {
        io:println("Retrying transaction");
    }

    json updateStatus;
    if (numberOfInvoices == numberOfRecordsInserted) {
        updateStatus = { "Status": "Data Inserted Successfully" };
    } else {
        updateStatus = { "Status": "Data Not Inserted", "Error": dbError.message};
    }

    res.setJsonPayload(updateStatus);
    return res;
}

public function addInvoice (http:Request req, Invoice invoice)
                    returns http:Response {

    http:Response res = new;

    json ret = insertInvoice(invoice);
    res.setJsonPayload(ret);

    io:println(ret);
    return res;
}

public function updateProcessFlag (http:Request req, int tid, Invoice inv)
                    returns http:Response {

    http:Response res = new;

    var ret = invoiceDB->update("UPDATE invoice_request SET PROCESS_FLAG = ?, RETRY_COUNT = ? where TRANSACTION_ID = ?",
        inv.processFlag, inv.retryCount, tid);

    json updateStatus;
    match ret {
        int retInt => {
            log:printInfo("Invoice is updated for tid " + tid);
            updateStatus = { "status": "invoice updated successfully" };
            res.statusCode = 202;
        }
        error err => {
            log:printError("Invoice is not updated for tid " + tid, err = err);
            updateStatus = { "status": "invoice not updated", "error": err.message };
            res.statusCode = 400;
        }
    }

    res.setJsonPayload(updateStatus);
    return res;
}

public function getInvoices (http:Request req)
                    returns http:Response {

    string baseSql = "SELECT * FROM invoice_request";

    map<string> params = req.getQueryParams();

    if (params.hasKey("processFlag")) {
        baseSql = baseSql + " where PROCESS_FLAG in (" + params.processFlag + ")";
    }

    if (params.hasKey("maxRetryCount")) {
        match <int> params.maxRetryCount {
            int n => {
                baseSql = baseSql + " and RETRY_COUNT <= " + n;
            }
            error err => {
                throw err;
            }
        }
    }

    baseSql = baseSql + " order by TRANSACTION_ID asc";

    if (params.hasKey("maxRecords")) {
        match <int> params.maxRecords {
            int n => {
                baseSql = baseSql + " limit " + n;
            }
            error err => {
                throw err;
            }
        }
    }

    io:println(baseSql);

    var ret = invoiceDB->select(baseSql, ());

    json jsonReturnValue;
    match ret {
        table dataTable => {
            jsonReturnValue = check <json>dataTable;
        }
        error err => {
            jsonReturnValue = { "Status": "Data Not Found", "Error": err.message };
        }
    }

    io:println(jsonReturnValue);
    http:Response res = new;
    res.setJsonPayload(untaint jsonReturnValue);

    return res;
}

public function insertInvoice(Invoice inv) returns (json) {
    json updateStatus;
    string sqlString =
    "INSERT INTO invoice_request(ORDER_NO,INVOICE_ID,SETTLEMENT_ID,COUNTRY_CODE,
        PROCESS_FLAG,ERROR_MESSAGE,RETRY_COUNT,ITEM_IDS,TRACKING_NUMBER,REQUEST) VALUES (?,?,?,?,?,?,?,?,?,?)";

    var ret = invoiceDB->update(sqlString, inv.orderNo, inv.invoiceId, inv.settlementId, inv.countryCode,
        inv.processFlag, inv.errorMessage, inv.retryCount, inv.itemIds, inv.trackingNumber, inv.request);

    match ret {
        int updateRowCount => {
            updateStatus = { "Status": "Data Inserted Successfully" };
        }
        error err => {
            updateStatus = { "Status": "Data Not Inserted", "Error": err.message };
        }
    }
    return updateStatus;
}

function onCommitFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " committed");
}

function onAbortFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " aborted");
}