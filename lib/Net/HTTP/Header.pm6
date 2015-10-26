role Net::HTTP::Header does Associative {
    has %!fields;

    multi method ASSIGN-KEY(::?CLASS:D: $key, $new) {
        my $field := self.AT-KEY($key) = $new;
        callwith(hc($key), $new);
    }
    multi method AT-KEY(::?CLASS:D: $key) is rw {
        my $field := %!fields{hc $key};
        Proxy.new(
            FETCH => method () { $field },
            STORE => method ($value) {
                $field = do given $field {
                    when *.so { @($field.Slip, $value) }
                    default   { $value }
                }
            }
        );
    }
    method BIND-KEY($key)   { callwith(hc $key) }
    method EXISTS-KEY($key) { callwith(hc $key) }
    method DELETE-KEY($key) { callwith(hc $key) }

    sub hc($key) { $key.split("-")>>.wordcase.join("-") }
}
