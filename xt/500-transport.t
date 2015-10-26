use Test;
plan 1;

use Net::HTTP::Transport;
use Net::HTTP::URL;
use Net::HTTP::Request;


subtest {
    my $url = Net::HTTP::URL.new('https://jigsaw.w3.org/HTTP/ChunkedScript');
    my $req = Net::HTTP::Request.new(:$url, :method<GET>, header => :User-Agent<perl6-net-http>);

    my $transport = Net::HTTP::Transport.new;
    my $res = $transport.round-trip($req);

    is $res.body.decode.lines.grep(/^0/).elems, 1000;
}, 'Transfer-Encoding: chunked';
