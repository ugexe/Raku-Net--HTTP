unit module Net::HTTP::Utils;

role IO::Socket::HTTP {
    has $.input-line-separator = "\r\n";
    has $.keep-alive is rw;
    has $.content-length is rw;
    has $.content-read;
    has $.is-chunked;

    my $promise = Promise.new;
    my $vow     = $promise.vow;

    method reset   { $promise = Promise.new; $vow = $promise.vow; $!content-length = Nil; $!content-read = Nil; }
    method result  { $ = await $promise; }
    method promise { $ = $promise }

    # Currently assumes these are called in a specific order
    method get(Bool :$bin where True, :$nl = $!input-line-separator, Bool :$chomp = True) {
        my @sep      = $nl.ords;
        my $sep-size = @sep.elems;
        my @buf;
        while $.recv(1, :bin) -> \data {
            @buf.append: data.contents;
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
        supply {
            my $cl = $!content-length;
            my $cr = $!content-read;
            loop {
                if $.recv($cl, :bin) -> \data {
                    my $d = buf8.new(data);
                    $cr  += $d.bytes;
                    emit($d);
                    last if $cl && $cr >= $cl;
                }
            }
            self.reset;
            self.close() unless ?$!keep-alive;
            $vow.keep(self);
            done();
        }
    }

    method supply-dechunked {
        supply {
            my $nl = $!input-line-separator;
            my @sep = $nl.ords;
            my $nl-size = $nl.ords.elems;

            loop {
                my $size-line = self.get(:bin).unpack('A*');
                my $size      = :16($size-line);
                last if $size == 0;
                if $.recv($size, :bin) -> \data {
                    my $d = buf8.new(data);
                    $!content-read += $d.bytes;
                    emit($d);
                }
                die "invalid chunk" unless self.recv($nl-size, :bin).contents ~~ @sep;
                $!content-read += $nl-size;
                last if $!content-length && $!content-read >= $!content-length;
            }
            self.reset;
            self.close() unless $!keep-alive;
            $vow.keep(self);
            done();
        }
    }
}

# header-case
sub hc(Str:D $str) is export {
    $str.split("-")>>.wordcase.join("-")
}
