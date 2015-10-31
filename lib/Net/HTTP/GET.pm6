use Net::HTTP::Interfaces;
use Net::HTTP::Transport;
use Net::HTTP::Request;
use Net::HTTP::Response;
use Net::HTTP::URL;

our $transport = Net::HTTP::Transport.new;

class Net::HTTP::GET {
    proto method CALL-ME(|) {*}
    multi method CALL-ME(Str $abs-url, :$body?, |c --> Response) {
        my $req = self!url2req($abs-url);
        $req.body = $body;
        samewith($req, |c);
    }
    multi method CALL-ME(Request $req, Response ::RESPONSE = Net::HTTP::Response --> Response) {
        self!round-trip($req, RESPONSE);
    }

    # a round-tripper that follow redirects
    method !round-trip($req, Response ::RESPONSE) {
        my $response = $transport.round-trip($req, RESPONSE) but ResponseBodyDecoder;
        given $response.status-code {
            when /^3\d\d$/ {
                # make an absolute url. this should be incorporated into Net::HTTP::URL
                my $url = ~$response.header<Location>.first(*.so);
                $url = Net::HTTP::URL.new: "{$req.url.scheme}://{$req.url.host}{$url}" unless $url ~~ /\w+? \: \/ \//;
                $response = self!round-trip($req.new(:$url, :method<GET>, :body($req.body)), RESPONSE);
            }
        }
        $response;
    }

    method !url2req($url-str --> Request) {
        my $url = Net::HTTP::URL.new($url-str);
        my $req = Net::HTTP::Request.new: :$url, :method<GET>,
            header => :Connection<keep-alive>, :User-Agent<perl6-net-http>;
    }
}
