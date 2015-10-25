use Net::HTTP::Interfaces;
use Net::HTTP::Utils;

# Ideally we want to store the entire response as $!raw bytes and make
# status-line, header, body, etc as methods that read from (while caching
# their results somehow) $!raw.  While doing this for the sake of the $!body
# is clear, it should be noted that this should also be done with the headers
# so that switching between HTTP1 and HTTP2 implementations is easier.
constant nl = "\r\n\r\n";

class Net::HTTP::Response does Response {
    has $.status-line;
    has %.header;
    has $.body is rw;
    has %.trailer;

    proto method new(|) {*}
    multi method new(:$status-line, :%header, :$body, :%trailer, *%_) {
        # This should be the main constructor for creating response objects as
        # using all named parameters makes it easier when multiple positionals
        # could be a Buf (think HTTP2 headers + response body both as :bin)
        self.bless(:$status-line, :%header, :$body, :%trailer, |$_);
    }
    multi method new(Buf $raw, *%_) {
        # An easy way to create a response object for an entire socket read
        # i.e. `::("$?CLASS").new($socket.recv(:bin))`
        my $nl       = "\r\n";
        my @sep      = "{$nl}{$nl}".ords;
        my $sep-size = @sep.elems;
        my (@hbuf, $bbuf);

        for @($raw.contents).pairs -> $data {
            @hbuf.append: $data.value;
            $bbuf = $raw[($data.key+1)..*] and last if @hbuf[*-($sep-size)..*] ~~ @sep;
        }

        @hbuf = @hbuf ?? buf8.new(@hbuf) !! Buf;
        $bbuf = $bbuf ?? buf8.new($bbuf) !! Buf;

        my @headers     = @hbuf>>.unpack('A*').split($nl).grep(*.so);
        my $status-line = %_<status-line> // (@headers.shift if @headers[0] ~~ self!status-line-matcher);
        my %header andthen do { %header{$_[0]} = $_[1] for @headers>>.split(/':' \s+/, 2) }

        samewith(:$status-line, :%header, :body($bbuf), |%_);
    }


    method status-code { $!status-line ~~ self!status-line-matcher andthen return ~$_[0] }
    method !status-line-matcher { $ = rx/^ 'HTTP/' \d [\.\d]? \s (\d\d\d) \s/ }
}
