import ballerina/http;
import ballerina/log;
import ballerina/mime;
import ballerina/swagger;

endpoint http:Listener ep0 { 
    host: "localhost",
    port: 8088
};

@swagger:ServiceInfo { 
    title: "OP-FE Payment API",
    description: "OP-FE Payment",
    serviceVersion: "0.1.0",
    contact: {name: "OP-FE Team", email: "team@op-fe.com", url: ""}
}
@http:ServiceConfig {
    basePath: "/op-fe"
}
service OPFEPaymentAPI bind ep0 {

    @swagger:ResourceInfo {
        summary: "Gets the version of OP-FE.",
        tags: ["version"],
        description: "Gets the version of OP-FE."
    }
    @http:ResourceConfig { 
        methods:["GET"],
        path:"/version"
    }
    getVersion (endpoint outboundEp, http:Request req) {
        http:Response res = getVersion(req);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @swagger:ResourceInfo {
        summary: "Capture Async, receive requests and enqueue CaptureRequest",
        tags: ["v2-payments"],
        description: "Capture Async, receive requests and enqueue CaptureRequest",
        parameters: [
            {
                name: "referenceId",
                inInfo: "path",
                description: "Reference Id", 
                required: true, 
                allowEmptyValue: ""
            },
            {
                name: "Api-Key",
                inInfo: "header",
                description: "The key used to validate the client access to API", 
                required: true, 
                allowEmptyValue: ""
            },
            {
                name: "Context-Id",
                inInfo: "header",
                description: "The context to be associated with the request", 
                required: true, 
                allowEmptyValue: ""
            }
        ]
    }
    @http:ResourceConfig { 
        methods:["POST"],
        path:"/v2/payments/ref/{referenceId}/capture/async",
        body:"payment"
    }
    addPayment (endpoint outboundEp, http:Request req, string referenceId, Payment payment) {
        http:Response res = addPayment(req, referenceId, payment);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

}
