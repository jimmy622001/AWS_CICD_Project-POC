const synthetics = require('Synthetics');
const log = require('SyntheticsLogger');
const https = require('https');
const http = require('http');

// Import AWS X-Ray SDK for tracing
const AWSXRay = require('aws-xray-sdk-core');
const AWS = AWSXRay.captureAWS(require('aws-sdk'));

// Main handler function for the canary
const apiCanaryBlueprint = async function() {
    // Get configuration from environment variables
    const API_ENDPOINT = process.env.API_ENDPOINT;
    const HTTP_METHOD = process.env.HTTP_METHOD || 'GET';
    const EXPECTED_STATUS = parseInt(process.env.EXPECTED_STATUS || '200', 10);
    const PROJECT_NAME = process.env.PROJECT_NAME || 'unknown';
    const ENVIRONMENT = process.env.ENVIRONMENT || 'unknown';
    
    // Start the API canary execution
    log.info(`Starting API canary for ${API_ENDPOINT}`);
    
    // Record start time for latency calculation
    const startTime = Date.now();
    
    // Prepare request options
    const url = new URL(API_ENDPOINT);
    const options = {
        hostname: url.hostname,
        port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: url.pathname + url.search,
        method: HTTP_METHOD,
        headers: {
            'User-Agent': 'AWS-Synthetics-Canary',
            'X-Canary-Project': PROJECT_NAME,
            'X-Canary-Environment': ENVIRONMENT
        }
    };
    
    // Execute the HTTP request
    try {
        const response = await makeRequest(options, url.protocol === 'https:');
        
        // Calculate latency
        const latency = Date.now() - startTime;
        log.info(`Request completed in ${latency}ms`);
        
        // Check if status code matches expected value
        if (response.statusCode !== EXPECTED_STATUS) {
            throw new Error(`Expected status code ${EXPECTED_STATUS}, but got ${response.statusCode}`);
        }
        
        // Parse and validate response body if it's JSON
        try {
            const responseBody = JSON.parse(response.body);
            log.debug('Response body (parsed):', responseBody);
        } catch (e) {
            log.debug('Response is not JSON or could not be parsed');
            log.debug('Response body:', response.body);
        }
        
        // Publish custom metrics
        publishMetrics({
            'ResponseTime': latency,
            'StatusCode': response.statusCode,
            'Success': 1
        });
        
        return {
            success: true,
            responseCode: response.statusCode,
            latency: latency
        };
    } catch (error) {
        log.error(`Request failed: ${error.message}`);
        
        // Publish failure metrics
        publishMetrics({
            'Success': 0,
            'Error': 1
        });
        
        throw error;
    }
};

// Helper function to make HTTP/HTTPS requests
function makeRequest(options, isHttps) {
    return new Promise((resolve, reject) => {
        const protocol = isHttps ? https : http;
        
        const req = protocol.request(options, (res) => {
            let responseBody = '';
            
            res.on('data', (chunk) => {
                responseBody += chunk;
            });
            
            res.on('end', () => {
                resolve({
                    statusCode: res.statusCode,
                    headers: res.headers,
                    body: responseBody
                });
            });
        });
        
        req.on('error', (error) => {
            reject(error);
        });
        
        req.end();
    });
}

// Helper function to publish custom CloudWatch metrics
function publishMetrics(metrics) {
    Object.keys(metrics).forEach((metricName) => {
        synthetics.publishMetric(metricName, 'Count', metrics[metricName]);
    });
}

// Export the handler function for Synthetics
exports.handler = async () => {
    return await apiCanaryBlueprint();
};