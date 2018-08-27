import wso2/ftp;
import ballerina/io;
import ballerina/config;

endpoint ftp:Client invoiceSFTP {
    protocol: ftp:SFTP,
    host: config:getAsString("op-be.invoice.sftp.host"),
    port: config:getAsInt("op-be.invoice.sftp.port"),
    secureSocket: {
        basicAuth: {
            username: config:getAsString("op-be.invoice.sftp.username"),
            password: config:getAsString("op-be.invoice.sftp.password")
        }
    },
    path:config:getAsString("op-be.invoice.sftp.path") + "/original"
};

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

service monitor bind invoiceSFTP {

    fileResource (ftp:WatchEvent m) {

        foreach v in m.addedFiles {

            io:println("New invoice received : ", v.path);
            var invoiceOrError = invoiceSFTPClient -> get(v.path);

            match invoiceOrError {

                io:ByteChannel channel => {
                    io:CharacterChannel characters = new(channel, "utf-8");
                    xml invoice = check characters.readXml();
                    _ = channel.close();

                    boolean success = handleInvoice(invoice);

                    if(success) {
                        archiveInvoice(v.path);
                    }
                }

                error err => {
                    io:println("An error occured in listening to newly added files");
                }
            }
        }

        foreach v in m.deletedFiles {
            io:println("Invoice deleted : ", v.path);
        }
    }
}

function handleInvoice(xml invoice) returns boolean {
    return true;
}

function archiveInvoice(string  path) {
    string archivePath = config:getAsString("op-be.invoice.sftp.path") + "/archive/" + getFileName(path);
    _ = invoiceSFTPClient -> rename(path, archivePath);
    io:println("Archived invoice path : ", archivePath);
}

function erroredInvoice(string path) {
    string erroredPath = config:getAsString("op-be.invoice.sftp.path") + "/error/" + getFileName(path);
    _ = invoiceSFTPClient -> rename(path, erroredPath);
    io:println("Errored invoice path : ", erroredPath);
}

function getFileName(string path) returns string {
    string[] tmp = path.split("/");
    int size = lengthof tmp;
    return tmp[size-1];
}