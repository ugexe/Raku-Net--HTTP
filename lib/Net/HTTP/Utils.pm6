unit module Net::HTTP::Utils;

role IO::Socket::HTTP {
    has $.input-line-separator = "\r\n";
    has $.keep-alive is rw;
    has $.content-length is rw;
    has $.content-read;
    has $.is-chunked is rw;

    my $promise = Promise.new;
    my $vow     = $promise.vow;

    method reset {
        $promise         = Promise.new;
        $vow             = $promise.vow;
        $!content-length = Nil;
        $!content-read   = Nil;
        $!is-chunked     = Nil;
    }
    method result  { $ = await $promise; }
    method promise { $ = $promise }

    # Currently assumes these are called in a specific order
    method get(Bool :$bin where True, :$nl = $!input-line-separator, Bool :$chomp = True) {
        my @sep      = $nl.ords;
        my $sep-size = @sep.elems;
        my @buf;
        while (my $data = self.recv(1, :bin)).defined {
            @buf.append: $data.contents;
            next unless @buf.elems >= $sep-size;
            last if @buf[*-($sep-size)..*] ~~ @sep;
        }

        @buf ?? ?$chomp ?? buf8.new(@buf[0..*-($sep-size+1)]) !! buf8.new(@buf) !! Buf;
    }

    method lines(Bool :$bin where True, :$nl = $!input-line-separator) {
        gather while (my $line = self.get(:bin, :$nl)).defined {
            take $line;
        }
    }


    # Currently only for use on the body due to content-length
    method supply {
        return self!supply-dechunked if ?self.is-chunked;
        supply {
            loop {
                my $buffered-size = 0;
                loop {
                    my $bytes-needed = ($!content-length - $buffered-size) || last;
                    if $.recv($bytes-needed, :bin) -> \data {
                        my $d = buf8.new(data);
                        $!content-read += $buffered-size += $d.bytes;
                        emit($d);
                    }
                    last if $buffered-size == $!content-length;
                }

                last if $!content-read >= $!content-length;
            }
            self.reset;
            self.close() unless $!keep-alive;
            $vow.keep(True);
            done();
        }
    }

    method !supply-dechunked {
        supply {
            my $nl = $!input-line-separator;
            my @sep = $nl.ords;
            my $nl-size = $nl.ords.elems;

            loop {
                my $size-line = self.get(:bin).unpack('A*');
                my $size      = :16($size-line);
                last if $size == 0;

                my $buffered-size = 0;
                loop {
                    my $bytes-needed = ($size - $buffered-size) || last;
                    if $.recv($bytes-needed, :bin) -> \data {
                        my $d = buf8.new(data);
                        $!content-read += $buffered-size += $d.bytes;
                        emit($d);
                    }
                    last if $buffered-size == $size;
                }

                die "invalid chunk" unless self.recv($nl-size, :bin).contents ~~ @sep;
                $!content-read += $nl-size;
                last if $!content-length && $!content-read >= $!content-length;
            }
            self.reset;
            self.close() unless $!keep-alive;
            $vow.keep(True);
            done();
        }
    }
}

# header-case
sub hc(Str:D $str) is export {
    $str.split("-")>>.wordcase.join("-")
}
