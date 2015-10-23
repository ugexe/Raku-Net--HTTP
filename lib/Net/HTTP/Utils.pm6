unit module Net::HTTP::Utils;

role IO::Socket::HTTP {
    has $.input-line-separator = "\r\n";

    method get(Bool :$bin where True) {
        my @sep      = $.input-line-separator.ords;
        my $sep-size = @sep.elems;
        my @buf;

        while $.recv(1, :bin) -> \data {
            @buf.append: data.contents;
            last if @buf[*-($sep-size)..*] ~~ @sep;
        }

        @buf ?? buf8.new(@buf[0..*-($sep-size+1)]) !! Buf;
    }

    method lines(Bool :$bin where True) {
        gather while (my $line = self.get(:bin)).defined {
            take $line;
        }
    }
}

sub ChunkedReader(buf8 $buf) is export {
    my @data;
    my $i = 0;

    loop {
        my $size-line;
        loop {
            last if $i == $buf.bytes;
            $size-line ~= $buf.subbuf($i++,1).decode('latin-1');
            last if $size-line ~~ /\r\n/;
        }
        my $size = :16($size-line.substr(0,*-2));
        last if $size == 0;
        @data.push: $buf.subbuf($i,$size);
        $i += $size + 2; # 1) \r 2) \n
        last if $i == $buf.bytes;
    }

    my buf8 $r = @data.reduce(-> $a is copy, $b { $a ~= $b });
    return $r;
}

# header-case
sub hc(Str:D $str) is export {
    $str.split("-")>>.wordcase.join("-")
}