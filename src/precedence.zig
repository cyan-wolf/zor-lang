
pub const Precendence = enum {
    none,
    assignment, // =
    p_or, // or
    p_and, // and
    equality, // == !=
    comparison, // < > <= >=
    term, // + -
    factor, // * /
    unary, // ! - 
    call, // . ()
    primary,
};
