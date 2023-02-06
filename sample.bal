import ballerina/http;
import ballerina/io;
import ballerinax/aws.s3;

const string ACCESS_KEY_ID = "AKIAR6WGL7MONTWGESFJ";
const string SECRET_ACCESS_KEY = "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";
const string US_EAST_1_REGION = "us-east-1";
const int NUMBER_OF_HEADERS_IN_CSV = 1;

final s3:Client amazonS3Client = check new ({
    accessKeyId: ACCESS_KEY_ID,
    secretAccessKey: SECRET_ACCESS_KEY,
    region: US_EAST_1_REGION
});

// INFO: Use a country name such as the "United States" to invoke this service.
// Disclaimer: The movies-tv-shows.csv file consists of a reduced version of
// the Netflix movies and TV shows dataset, which is publicly available at https://www.kaggle.com/shivamb/netflix-shows.

service / on new http:Listener(8090) {
    resource function get tv_shows(string country) returns json|http:BadRequest|error {
        if country.length() == 0 {
            http:BadRequest response = {body: "Country cannot be empty"};
            return response;
        }

        string requestedCountry = country;
        stream<byte[], io:Error?> movieCatalogResponse = check amazonS3Client->getObject("library-catalog",
        "movies-tv-shows.csv");

        byte[] allBytes = [];
        check from byte[] chunks in movieCatalogResponse
            do {
                allBytes.push(...chunks);
            };

        io:ReadableCharacterChannel readableCharacterChannel = new (check io:createReadableChannel(allBytes), "UTF-8");
        io:ReadableCSVChannel csvChannel = new (readableCharacterChannel, io:COMMA, NUMBER_OF_HEADERS_IN_CSV);
        stream<string[], io:Error?> csvStream = check csvChannel.csvStream();

        int tvShowCount = 0;
        check from string[] cells in csvStream
            where cells[1] == "TV Show" && cells[5] == requestedCountry
            do {
                tvShowCount += 1;
            };

        return {
            title: string `TV shows from ${requestedCountry}`,
            count: tvShowCount
        };
    }
}
