import ballerina/math;
import ballerina/io;

public function getVersion (http:Request req) returns http:Response {
    http:Response res = new;
    string resPayload = "{manifestVersion=1, name=\"OP-FE Payment\", branch=\"1.52.0\", version=\"1.52.0-2c331c5\",
                commit=\"2c331c532c3f90bcd10ddcaaccb38b60dfb81079\"}";
    res.setTextPayload(resPayload);

	return res;
}

public function addPayment (http:Request req, string referenceId, Payment payment)
                    returns http:Response {
    http:Response res = new;

    if (!req.hasHeader("Api-Key") || req.getHeader("Api-Key") != "hedge") {
        res.statusCode = 401;
        res.setTextPayload("No access. Wrong API key");
    } if (!req.hasHeader("Context-Id") || req.getHeader("Context-Id") != "ECOMM_US") {
        res.statusCode = 403;
        res.setTextPayload("The context is not valid or can not be used with this service");
        io:println(req.getHeader("Context-Id"));
    } else if (math:randomInRange(1,5) == 1) {
        res.statusCode = 500;
        res.setTextPayload("Error queuing the request");
    } else {
        res.statusCode = 201;
        res.setTextPayload("Capture queued successfully "+ untaint payment.amount);
    }

	return res;
}

