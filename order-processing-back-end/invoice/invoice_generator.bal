import wso2/ftp;
import ballerina/io;
import ballerina/task;
import ballerina/math;
import ballerina/runtime;
import ballerina/log;
import ballerina/http;
import ballerina/config;

int count;
task:Timer? timer;

endpoint ftp:Client invoiceSFTPClient {
    protocol: ftp:SFTP,
    host: config:getAsString("op-be.invoice.sftp.host"),
    port: config:getAsInt("op-be.invoice.sftp.port"),
    secureSocket: {
        basicAuth: {
            username: config:getAsString("op-be.invoice.sftp.username"),
            password: config:getAsString("op-be.invoice.sftp.password")
        }
    }
};

function main(string... args) {

    (function() returns error?) onTriggerFunction = generateInvoice;
    function(error) onErrorFunction = handleError;

    int interval = config:getAsInt("op-be.invoice.etl.interval");
    int delay = config:getAsInt("op-be.invoice.etl.initialDelay");

    timer = new task:Timer(onTriggerFunction, onErrorFunction,
        interval, delay = delay);

    timer.start();
    runtime:sleep(20000);
}

function generateInvoice() returns error? {
    int invoiceId = math:randomInRange(1,10000);
    string invoiceName = "ZECOMM" + invoiceId;
    log:printInfo("Generating invoice : " + invoiceName);

    xml invoices = xml `<ZECOMMINVOICE>
            <IDOC BEGIN="1">
            </IDOC>
        </ZECOMMINVOICE>`;

    xml invoiceHeader = xml `<EDI_DC40 SEGMENT="1">
            <TABNAM>EDI_DC40</TABNAM>
            <MANDT>301</MANDT>
            <DOCNUM>0000002345409334</DOCNUM>
            <DOCREL>740</DOCREL>
            <STATUS>30</STATUS>
            <DIRECT>1</DIRECT>
            <OUTMOD>4</OUTMOD>
            <IDOCTYP>ZECOMMINVOICE</IDOCTYP>
            <MESTYP>ZINVOICE</MESTYP>
            <SNDPOR>SAPECQ</SNDPOR>
            <SNDPRT>LS</SNDPRT>
            <SNDPRN>ECQCLNT301</SNDPRN>
            <RCVPOR>ZINVOICE</RCVPOR>
            <RCVPRT>LS</RCVPRT>
            <RCVPRN>ZECOMM_ECOM</RCVPRN>
            <CREDAT>20171215</CREDAT>
            <CRETIM>172035</CRETIM>
            <SERIAL>20171215172035</SERIAL>
       </EDI_DC40>`;

    // add invoice header
    invoices.selectDescendants("IDOC").setChildren(invoiceHeader);

    int numberOfInvoices = math:randomInRange(1,5);
    xml[] invoiceArray;
    foreach i in 1 ... numberOfInvoices {
        xml invoice = xml `<ZECOMMINVOICE SEGMENT="1">
                    <ZBLCORD>DEUAT{{math:randomInRange(1,1000000)}}</ZBLCORD>
                    <VBELN>{{math:randomInRange(1,10000)}}</VBELN>
                    <DMBTR>{{math:ceil(math:random()*100)}}</DMBTR>
                    <WAERK>EUR</WAERK>
                    <ZDMBTR>0.00</ZDMBTR>
                    <LAND1>DE</LAND1>
                </ZECOMMINVOICE>`;

        invoiceArray[i-1] = invoice;
    }

    foreach invoice in invoiceArray {
        xml children = invoices.selectDescendants("IDOC").* + invoice;
        invoices.selectDescendants("IDOC").setChildren(children);
    }

    io:println(invoices);

    // uploading invoices to SFTP
    string invoiceAsString = <string> invoices;
    io:ByteChannel bchannel = io:createMemoryChannel(invoiceAsString.toByteArray("UTF-8"));
    string path = config:getAsString("op-be.invoice.sftp.path") + "/original/" + invoiceName + ".xml";

    log:printInfo("Uploading invoice : " + invoiceName + " to sftp");
    error? filePutErr = invoiceSFTPClient -> put(path, bchannel);

    return ();
}

function handleError(error e) {
    log:printError("Error in generating invoice", err = e);
    timer.stop();
}
