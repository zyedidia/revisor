module core.result;

struct Result(T) {
    this(T s) {
        value = s;
        has_val = true;
    }

    this(Error e) {
        error = e;
        has_val = false;
    }

    Error err() {
        if (!has_val) {
            return error;
        }
        return Error.none();
    }

    T get() {
        assert(has_val);
        return value;
    }

private:
    bool has_val;
    union {
        T value;
        Error error;
    };
}
