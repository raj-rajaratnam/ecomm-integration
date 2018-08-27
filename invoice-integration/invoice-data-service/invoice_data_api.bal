import ballerina/http;
import ballerina/log;
import ballerina/mysql;

endpoint http:Listener invoiceListener {
    host: "localhost",
    port: 8089
};

@http:ServiceConfig {
    basePath: "/invoice"
}
service<http:Service> invoiceAPI bind invoiceListener {

    @http:ResourceConfig {
        methods:["POST"],
        path: "/batch/",
        body: "invoices"
    }
    addInvoices (endpoint outboundEp, http:Request req, Invoices invoices) {
        http:Response res = addInvoices(req, invoices);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["POST"],
        path: "/",
        body: "invoice"
    }
    addInvoice (endpoint outboundEp, http:Request req, Invoice invoice) {
        http:Response res = addInvoice(req, invoice);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["GET"],
        path: "/"
    }
    getAllInvoices (endpoint outboundEp, http:Request req) {
        http:Response res = getInvoices(untaint req);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["PUT"],
        path: "/process-flag/{tid}",
        body: "invoice"
    }
    updateProcessFlag (endpoint outboundEp, http:Request req, int tid, Invoice invoice) {
        http:Response res = updateProcessFlag(req, tid, invoice);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

}
