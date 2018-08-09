# Packaging

`Term::ANSIColor` needs to be 4.06, but it won't be included by carton because
`carton` think it's part of the platform. So move it out of the way before
running `carton` or `fatpack pack`.
