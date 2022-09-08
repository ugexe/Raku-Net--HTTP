## Net::HTTP

Interfaces and default implementations for rolling your own http client and/or components

## Synopsis

    use Net::HTTP::GET;
    my %header   = :Connection<keep-alive>;
    my $response = Net::HTTP::GET("http://httpbin.org/ip", :%header);
    say $response.content;


    use Net::HTTP::POST;
    my $body     = Buf.new("a=b&c=d&f=".ords);
    my $response = Net::HTTP::POST("http://httpbin.org/post", :$body);
    say $response.content;

## How do I...?

#### Use a proxy

Simply add a proxy method to your client or transport object. For instance, to simply return a url
from a string you could do:

    my $transport = Net::HTTP::Transport.new;
    $transport does role { 
        method proxy { ::('Net::HTTP::URL').new("http://proxy-lord.org") }
    }

But you could also implement rotating proxies, proxy from `$*ENV`, etc

## Client Implementations

#### Net::HTTP::GET

    my $response = Net::HTTP::GET("http://httpbin.org/ip");

Simple access to the http `GET` client api.

#### Net::HTTP::POST

    my $body = Buf.new("a=1&b=2".ords);
    my $response = Net::HTTP::POST("http://httpbin.org/post", :$body);

Simple access to the http `POST` client api (Still lacking anything beyond basic functionality)

#### Net::HTTP::Transport

        my $url = Net::HTTP::URL.new($abs-url);
        my $req = Net::HTTP::Request.new(:$url, :method<GET>, :User-Agent<raku-net-http>);
        my $transport = Net::HTTP::Transport.new;
        my $response  = $transport.round-trip($req);

A high level round-robin implementation that attempts connection caching and is thread safe.
For a user-agent level implementation that handles cookies, redirects, auth, etc then use
a `Net::HTTP::Client`. Can provide an alternative `Response` object as an argument.

    > use HTTP::SomethingElse::Response;
    > my \ALTRESPONSE = HTTP::SomethingElse::Response;
    > my $response    = $transport.round-trip($req, ALTRESPONSE);

#### Net::HTTP::Client

    # NYI

Highest level of http client implementation.

## Interface Default Implementations

Most `Net::HTTP` components can be swapped out for generic alternatives. `Net::HTTP` provides a set of interfaces (see: [Net::HTTP::Interfaces](https://github.com/ugexe/Raku-Net--HTTP/blob/main/lib/Net/HTTP/Interfaces.rakumod) and the other included classes in `Net::HTTP` can be viewed as `default` implementations.

#### Net::HTTP::URL

    my $url = Net::HTTP::URL.new("http://google.com/");

Create a `url` object to provide an api to the url parts, such as *scheme*, *host*, and *port*.

    > say ~$url
    http://google.com/
    > say $url.host;
    google.com

#### Net::HTTP::Request

    my $url     = Net::HTTP::URL.new("http://google.com/");
    my $request = Net::HTTP::Request.new(:$url, :method<GET>, header => :Host<google.com>);

Create a `Request` object which provides an api to generating an over-the-wire or human readable representation
of an http request. `.raw` gives a binary representation, and `.Str` gives a utf8 encoded version.

    > my $socket = IO::Socket::INET.new(:host<google.com>, :port(80));
    > $socket.write($request.raw)

#### Net::HTTP::Response

    my $response-from-args = Net::HTTP::Response.new(:$status-line, :%header, :$body);
    my $response-from-buf  = Net::HTTP::Response.new($response-as-buf);

Creates a `Response` object that provides an api to parsing an http response. It can be created with named arguments
representing the http message parts, or it can be given a raw `Blob`.

    > my $data = buf8.new andthen while $socket.recv(:bin) -> d { $data ~= $d }
    > my $response = Net::HTTP::Response.new($data)

#### Net::HTTP::Dialer

    my $url     = Net::HTTP::URL.new("http://google.com/");
    my $request = Net::HTTP::Request.new(:$url, :method<GET>, header => :Host<google.com>);
    my $socket  = Net::HTTP::Dialer.new.dial($request);

A role for providing access to scheme appropriate socket connections.
