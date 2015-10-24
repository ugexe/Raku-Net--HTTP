use Net::HTTP::Interfaces;
use Net::HTTP::Utils;

# Ideally we want to store the entire response as $!raw bytes and make
# status-line, header, body, etc as methods that read from (while caching
# their results somehow) $!raw.  While doing this for the sake of the $!body
# is clear, it should be noted that this should also be done with the headers
# so that switching between HTTP1 and HTTP2 implementations is easier.

class Net::HTTP::Response does Response {
    has $.status-line;
    has %.header;
    has $.body;

    proto method new(|) {*}
    multi method new($body, Buf[uint8] $raw-headers, |c) {
        # header as a single Buf
        samewith($body, $raw-headers.unpack('A*'), |c)
    }
    multi method new($body, Str $decoded-headers, |c) {
        # header as a single string
        samewith($body, $decoded-headers.split("\r\n"), |c);
    }
    multi method new($body, @headers, Str :$status-line is copy, |c) {
        # headers (Str or Buf) that have already been split line by line
        my @header-strs = flat @headers.map: {$_.isa(Str) ?? $_ !! $_.unpack("A*") }
        my $status      = $status-line || (@header-strs.shift if @header-strs[0] ~~ self!status-line-matcher);
        my %header andthen do { %header{$_[0]} = $_[1] for @header-strs>>.split(/':' \s+/, 2) }
        samewith($body, :status-line($status), |%header, |c);
    }
    multi method new($body, :$status-line, *%header) {
        # Not sure that %header should be slurpy as it makes passing in other named arguments
        # (like :$status-line) and the trailers (which are also kv pairs) less trivial.
        # It stands this way currently as it allows us to try and use HTTP::UserAgent's
        # Response object, but will likely be removed as it's Response object does not allow
        # fine grained control over the object (sets its own status line for instance) which
        # makes an elegant solution difficult. We should look into creating a better universal 
        # constructor template for all Response type objects.
        self.bless(:$body, :$status-line, :%header);
    }

    method status-code { $!status-line ~~ self!status-line-matcher andthen return ~$_[0] }
    method !status-line-matcher { $ = rx/^ 'HTTP/' \d [\.\d]? \s (\d\d\d) \s/ }
}
