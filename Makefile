.PHONY:

# this is a little ugly but this pod file will throw an error otherwise
.PHONY: fatpack
fatpack:
	mv local/lib/perl5/Parse/DMIDecode/Examples.pod /tmp/Examples.pod
	@carton exec fatpack pack bin/send_report.pl > bin/send_report.packed.pl
	mv /tmp/Examples.pod local/lib/perl5/Parse/DMIDecode/Examples.pod
