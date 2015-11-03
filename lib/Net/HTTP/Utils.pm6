unit module Net::HTTP::Utils;

# ease transition to \r\n graphme stuff
my $CRLF = Buf.new(13, 10);

role IO::Socket::HTTP {
    has $.closing is rw = False;
    has $.promise = Promise.new;

    # Currently assumes these are called in a specific order per request
    method get(Bool :$bin where True, Bool :$chomp = True) {
        my @sep      = $CRLF.contents;
        my $sep-size = +@sep;
        my $buf = buf8.new;
        loop {
            $buf ~= $.recv(1, :bin);
            last if $buf.tail($sep-size) ~~ @sep;
        }
        ?$chomp ?? $buf.subbuf(0, $buf.elems - $sep-size) !! $buf;
    }

    method lines(Bool :$bin where True) {
        gather while $.get(:bin) -> \data {
            take data;
        }
    }

    # Currently only for use on the body due to content-length
    method supply(:$buffer = Inf, Bool :$chunked = False) {
        # to make it easier in the transport itself we will simply
        # ignore $buffer if ?$chunked
        supply {
            my $bytes-read = 0;
            my @sep        = $CRLF.contents;
            my $sep-size   = @sep.elems;
            my $want-size  = ($chunked ?? :16(self.get(:bin).unpack('A*')) !! $buffer) || 0;

            loop {
                my $buffered-size = 0;
                if $want-size {
                    loop {
                        my $bytes-needed = ($want-size - $buffered-size) || last;
                        if $.recv($bytes-needed, :bin) -> $data {
                            $bytes-read    += $data.bytes;
                            $buffered-size += $data.bytes;
                            emit($data);
                        }
                        last if $buffered-size == $bytes-read | 0;
                    }
                }

                if ?$chunked {
                    my @validate = $.recv($sep-size, :bin).contents;
                    die "Chunked encoding error: expected separator ords '{@sep.perl}' not found (got: {@validate.perl})" unless @validate ~~ @sep;
                    $bytes-read += $sep-size;
                    $want-size = :16(self.get(:bin).unpack('A*'));
                }
                done() if $want-size == 0 || $bytes-read >= $buffer || $buffered-size == 0;
            }
        }
    }

    method init {
        state $lock += 1;
        if $!promise.status ~~ Kept && $lock == 1 {
            unless $.closed {
                $!promise = Promise.new;
                $lock = 0;
                return self;
            }
        }
        $lock--;
    }

    method release {
        $!promise.keep(True);
    }

    method close {
        $!closing = True;
        $!promise.break(False);
        nextsame;
    }

    method closed {
        return True if $!promise.status ~~ Broken;
        try {
            $.read(0);
            # if the socket is closed it will give a different error for read(0)
            CATCH { when /'Out of range'/ { return False } }
        }
    }
}

# header-case
sub hc(Str:D $str) is export {
    $ = $str.split("-").map(*.wordcase).join("-");
}
