use Test;
plan 1;

use Net::HTTP::GET;

subtest {
    my $url = "http://httpbin.org";

    my $response200 = Net::HTTP::GET($url ~ '/status/200');
    is $response200.status-code, 200;

    my $response400 = Net::HTTP::GET($url ~ '/status/400');
    is $response400.status-code, "400";
}, "Basic; GET";
