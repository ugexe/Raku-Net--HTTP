unit module Net::HTTP::Utils;

role IO::Socket::HTTP {
    has $.input-line-separator is rw = "\r\n";
    has $.closing is rw = False;
    has $.promise = Promise.new;

    # Currently assumes these are called in a specific order per request
    method get(Bool :$bin where True, :$nl = $!input-line-separator, Bool :$chomp = True) {
        my @sep      = $nl.ords;
        my $sep-size = +@sep;
        my $buf = buf8.new;
        while $.recv(1, :bin) -> \data {
            $buf ~= data;
            next unless $buf.elems >= $sep-size;
            last if $buf.tail($sep-size) ~~ @sep;

        }
        ?$chomp ?? $buf.subbuf(0, $buf.elems - $sep-size) !! $buf;
    }

    method lines(Bool :$bin where True, :$nl = $!input-line-separator) {
        gather while $.get(:bin, :$nl) -> \data {
            take data;
        }
    }

    # Currently only for use on the body due to content-length
    method supply(:$buffer = Inf, Bool :$chunked = False) {
        # to make it easier in the transport itself we will simply
        # ignore $buffer if ?$chunked
        supply {
            my $bytes-read = 0;
            my $ils       = $!input-line-separator;
            my @sep       = $ils.ords;
            my $sep-size  = $ils.ords.elems;
            my $want-size = ($chunked ?? :16(self.get(:bin).unpack('A*')) !! $buffer) || 0;
            loop {
                last if $want-size == 0;
                my $buffered-size = 0;
                loop {
                    my $bytes-needed = ($want-size - $buffered-size) || last;
                    if $.recv($bytes-needed, :bin) -> \data {
                        my $d = buf8.new(data);
                        $bytes-read += $buffered-size += $d.bytes;
                        emit($d);
                    }
                    last if $buffered-size == $want-size;
                }

                if ?$chunked {
                    my @validate = $.recv($sep-size, :bin).contents;
                    die "Chunked encoding error: expected separator ords '{@sep.perl}' not found (got: {@validate.perl})" unless @validate ~~ @sep;
                    $bytes-read += $sep-size;
                    $want-size = :16(self.get(:bin).unpack('A*'));
                }

                last if $bytes-read >= $buffer;
            }
            done();
        }
    }

    method init {
        state $lock += 1;
        if $!promise.status ~~ Kept && $lock == 1 {
            unless $.closed {
                $!promise = Promise.new;
                $lock = 0;
                return True
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
    $str.split("-").map(*.wordcase).join("-")
}
