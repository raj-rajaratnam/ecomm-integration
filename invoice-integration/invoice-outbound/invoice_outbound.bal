import ballerina/log;
import ballerina/http;
import ballerina/mysql;
import ballerina/config;
import ballerina/task;
import ballerina/runtime;
import ballerina/io;

endpoint http:Client invoiceDataEndpoint {
    url: config:getAsString("invoice.api.url")
};

endpoint http:Client opfeAPIEndpoint {
    url: config:getAsString("op-fe.api.url")
};

int count;
task:Timer? timer;
int interval = config:getAsInt("invoice.outbound.task.interval");
int delay = config:getAsInt("invoice.outbound.task.delay");
int maxRetryCount = config:getAsInt("invoice.outbound.task.maxRetryCount");
int maxRecords = config:getAsInt("invoice.outbound.task.maxRecords");
int apiKey = config:getAsInt("op-fe.api.key");


function main(string... args) {

    (function() returns error?) onTriggerFunction = doInvoiceETL;

    function(error) onErrorFunction = handleError;

    timer = new task:Timer(onTriggerFunction, onErrorFunction,
        interval, delay = delay);

    timer.start();
    runtime:sleep(200000);
}

function doInvoiceETL() returns  error? {

    log:printInfo("Calling invoiceDataEndpoint to fetch invoices");

    http:Request req = new;

    var response = invoiceDataEndpoint->get("?processFlag='N','E'&maxRecords=" + maxRecords
            + "&maxRetryCount=" + maxRetryCount);

    json invoices;
    match response {
        http:Response resp => {
            match resp.getJsonPayload() {
                json j => {invoices = j;}
                error err => {
                    log:printError("Response from invoiceDataEndpoint is not a json : " + err.message, err = err);
                    throw err;
                }
            }
        }
        error err => {
            log:printError("Error while calling invoiceDataEndpoint : " + err.message, err = err);
            throw err;
        }
    }

    foreach invoice in invoices {

        int tid = check <int> invoice.TRANSACTION_ID;
        string invoiceId = check <string> invoice.INVOICE_ID;
        string orderNo = check <string> invoice.ORDER_NO;
        int retryCount = check <int> invoice.RETRY_COUNT;

        json jsonPayload = untaint getOpfePaymentPayload(invoice);
        req.setJsonPayload(jsonPayload);
        req.setHeader("api-key",apiKey);
        string contextId = "ECOMM_" + check <string> invoice.COUNTRY_CODE;
        req.setHeader("Context-Id", contextId);

        log:printInfo("Calling op-fe to process invoice : " + invoiceId + ". Payload : " + jsonPayload.toString());

        response = opfeAPIEndpoint->post("/" + untaint orderNo + "/capture/async", req);

        match response {
            http:Response resp => {

                int httpCode = resp.statusCode;
                if (httpCode == 201) {
                    log:printInfo("Successfully processed invoice : " + invoiceId + " to op-fe");
                    updateProcessFlag(tid, retryCount, "C", "sent to op-fe");
                } else {
                    match resp.getTextPayload() {
                        string payload => {
                            log:printInfo("Failed to process invoice : " + invoiceId +
                                    " to op-fe. Error code : " + httpCode + ". Error message : " + payload);
                            updateProcessFlag(tid, retryCount + 1, "E", payload);
                        }
                        error err => {
                            log:printInfo("Failed to process invoice : " + invoiceId +
                                    " to op-fe. Error code : " + httpCode);
                            updateProcessFlag(tid, retryCount + 1, "E", "unknown error");
                        }
                    }
                }
            }
            error err => {
                log:printError("Error while calling op-fe for invoice : " + invoiceId, err = err);
                updateProcessFlag(tid, retryCount + 1, "E", "unknown error");
            }
        }
    }

    return ();
}

function getOpfePaymentPayload(json invoice) returns (json) {

    json paymentPayload = {
        "amount": invoice.AMOUNT,
        "totalAmount": invoice.TOTAL_AMOUNT,
        "currency": invoice.CURRENCY,
        "countryCode": invoice.COUNTRY_CODE,
        "invoiceId": invoice.INVOICE_ID,
        "additionalProperties":{
            "trackingNumber": invoice.TRACKING_NUMBER
        }
    };

    if (<string>invoice["SETTLEMENT_ID"] != "") {
        paymentPayload["settlementId"] = invoice.SETTLEMENT_ID;
    }

    string itemIds = check <string> invoice.ITEM_IDS;
    string[] itemIdsArray = itemIds.split(",");
    json itemIdsJsonArray = check <json> itemIdsArray;
    paymentPayload["itemIds"] = itemIdsJsonArray;

    return paymentPayload;
}

function handleError(error e) {
    log:printError("Error in processing invoices to op-fe", err = e);
    timer.stop();
}

function updateProcessFlag(int tid, int retryCount, string processFlag, string errorMessage) {

    json updateInvoice = {
        "processFlag": processFlag,
        "retryCount": retryCount,
        "errorMessage": errorMessage
    };

    http:Request req = new;
    req.setJsonPayload(untaint updateInvoice);

    var response = invoiceDataEndpoint->put("/process-flag/" + untaint tid, req);

    match response {
        http:Response resp => {
            int httpCode = resp.statusCode;
            if (httpCode == 202) {
                if (processFlag == "E" && retryCount > maxRetryCount) {
                    notifyOperation();
                }
            }
        }
        error err => {
            log:printError("Error while calling invoiceDataEndpoint", err = err);
        }
    }
}

function notifyOperation()  {
    log:printInfo("Notifying operations");
}