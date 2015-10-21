use Net::HTTP::Interfaces;

class Net::HTTP::Response does Response {
    has %.header;
    has $.body;

    method status-code { }
}
