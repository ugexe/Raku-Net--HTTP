unit module Net::HTTP::Utils;

role IO::HTTPReader is export {
    method header-supply {
        supply {
            state @crlf;
            while $.recv(1, :bin) -> \data {
                my $d = buf8.new(data).decode('latin-1');
                @crlf.push($d);
                emit($d);
                @crlf.shift if @crlf.elems > 4;
                last if @crlf ~~ ["\r", "\n", "\r", "\n"];
            }
            done();
        }
    }
    method body-supply {
        supply {
            while $.recv(:bin) -> \data {
                my $d = buf8.new(data);
                emit($d);
            }
            done();
        }
    }
    method trailer-supply { }
}

# decode a chunked buffer (ignores extensions)
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