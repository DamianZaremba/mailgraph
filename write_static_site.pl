#!/usr/bin/perl -w
use RRDs;
use POSIX qw(uname);

my $VERSION = "1.14";
my $host = (POSIX::uname())[1];
my $xpoints = 540;
my $points_per_sample = 3;
my $ypoints = 160;
my $ypoints_err = 96;
my $rrd = '/var/lib/mailgraph.rrd'; # path to where the RRD database is
my $rrd_virus = '/var/lib/mailgraph_virus.rrd'; # path to where the Virus RRD database is
my $dst_dir = '/var/www/vhosts/default/mailgraph';

my @graphs = (
	{ title => 'Last Day',   seconds => 3600*24,        },
	{ title => 'Last Week',  seconds => 3600*24*7,      },
	{ title => 'Last Month', seconds => 3600*24*31,     },
	{ title => 'Last Year',  seconds => 3600*24*365, },
);

my %color = (
	sent     => '000099', # rrggbb in hex
	received => '009900',
	rejected => 'AA0000', 
	bounced  => '000000',
	virus    => 'DDBB00',
	spam     => '999999',
);

sub rrd_graph(@) {
	my ($range, $file, $ypoints, @rrdargs) = @_;
	my $step = $range*$points_per_sample/$xpoints;
	# choose carefully the end otherwise rrd will maybe pick the wrong RRA:
	my $end  = time; $end -= $end % $step;
	my $date = localtime(time);
	$date =~ s|:|\\:|g unless $RRDs::VERSION < 1.199908;

	my ($graphret,$xs,$ys) = RRDs::graph($file,
		'--imgformat', 'PNG',
		'--title', 'Mail graphs for ' . $host,
		'--width', $xpoints,
		'--height', $ypoints,
		'--start', "-$range",
		'--end', $end,
		'--vertical-label', 'msgs/min',
		'--lower-limit', 0,
		'--units-exponent', 0, # don't show milli-messages/s
		'--lazy',
		'--color', 'SHADEA#ffffff',
		'--color', 'SHADEB#ffffff',
		'--color', 'BACK#ffffff',

		$RRDs::VERSION < 1.2002 ? () : ( '--slope-mode'),

		@rrdargs,

		'COMMENT:['.$date.']\r',
	);

	my $ERR=RRDs::error;
	die "ERROR: $ERR\n" if $ERR;
}

sub graph($$) {
	my ($range, $file) = @_;
	my $step = $range*$points_per_sample/$xpoints;
	rrd_graph($range, $file, $ypoints,
		"DEF:sent=$rrd:sent:AVERAGE",
		"DEF:msent=$rrd:sent:MAX",
		"CDEF:rsent=sent,60,*",
		"CDEF:rmsent=msent,60,*",
		"CDEF:dsent=sent,UN,0,sent,IF,$step,*",
		"CDEF:ssent=PREV,UN,dsent,PREV,IF,dsent,+",
		"AREA:rsent#$color{sent}:Sent    ",
		'GPRINT:ssent:MAX:total\: %8.0lf msgs',
		'GPRINT:rsent:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmsent:MAX:max\: %4.0lf msgs/min\l',

		"DEF:recv=$rrd:recv:AVERAGE",
		"DEF:mrecv=$rrd:recv:MAX",
		"CDEF:rrecv=recv,60,*",
		"CDEF:rmrecv=mrecv,60,*",
		"CDEF:drecv=recv,UN,0,recv,IF,$step,*",
		"CDEF:srecv=PREV,UN,drecv,PREV,IF,drecv,+",
		"LINE2:rrecv#$color{received}:Received",
		'GPRINT:srecv:MAX:total\: %8.0lf msgs',
		'GPRINT:rrecv:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmrecv:MAX:max\: %4.0lf msgs/min\l',
	);
}

sub graph_err($$) {
	my ($range, $file) = @_;
	my $step = $range*$points_per_sample/$xpoints;
	rrd_graph($range, $file, $ypoints_err,
		"DEF:bounced=$rrd:bounced:AVERAGE",
		"DEF:mbounced=$rrd:bounced:MAX",
		"CDEF:rbounced=bounced,60,*",
		"CDEF:dbounced=bounced,UN,0,bounced,IF,$step,*",
		"CDEF:sbounced=PREV,UN,dbounced,PREV,IF,dbounced,+",
		"CDEF:rmbounced=mbounced,60,*",
		"AREA:rbounced#$color{bounced}:Bounced ",
		'GPRINT:sbounced:MAX:total\: %8.0lf msgs',
		'GPRINT:rbounced:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmbounced:MAX:max\: %4.0lf msgs/min\l',

		"DEF:virus=$rrd_virus:virus:AVERAGE",
		"DEF:mvirus=$rrd_virus:virus:MAX",
		"CDEF:rvirus=virus,60,*",
		"CDEF:dvirus=virus,UN,0,virus,IF,$step,*",
		"CDEF:svirus=PREV,UN,dvirus,PREV,IF,dvirus,+",
		"CDEF:rmvirus=mvirus,60,*",
		"STACK:rvirus#$color{virus}:Viruses ",
		'GPRINT:svirus:MAX:total\: %8.0lf msgs',
		'GPRINT:rvirus:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmvirus:MAX:max\: %4.0lf msgs/min\l',

		"DEF:spam=$rrd_virus:spam:AVERAGE",
		"DEF:mspam=$rrd_virus:spam:MAX",
		"CDEF:rspam=spam,60,*",
		"CDEF:dspam=spam,UN,0,spam,IF,$step,*",
		"CDEF:sspam=PREV,UN,dspam,PREV,IF,dspam,+",
		"CDEF:rmspam=mspam,60,*",
		"STACK:rspam#$color{spam}:Spam    ",
		'GPRINT:sspam:MAX:total\: %8.0lf msgs',
		'GPRINT:rspam:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmspam:MAX:max\: %4.0lf msgs/min\l',

		"DEF:rejected=$rrd:rejected:AVERAGE",
		"DEF:mrejected=$rrd:rejected:MAX",
		"CDEF:rrejected=rejected,60,*",
		"CDEF:drejected=rejected,UN,0,rejected,IF,$step,*",
		"CDEF:srejected=PREV,UN,drejected,PREV,IF,drejected,+",
		"CDEF:rmrejected=mrejected,60,*",
		"LINE2:rrejected#$color{rejected}:Rejected",
		'GPRINT:srejected:MAX:total\: %8.0lf msgs',
		'GPRINT:rrejected:AVERAGE:avg\: %5.2lf msgs/min',
		'GPRINT:rmrejected:MAX:max\: %4.0lf msgs/min\l',

	);
}

sub write_css() {
	open(CSS_FILE, ">$dst_dir/mailgraph.css");
	print CSS_FILE <<CSS;
* {
	margin: 0px;
	padding: 0px;
}

h1 {
	margin-top: 20px;
	margin-bottom: 30px;
        text-align: center;
}

h2 {
        padding: 2px 0px 2px 4px;
}

img {
	border: 0px;
}

a {
	text-decoration: none;
	color: #00e00e;
}

a:hover {
	text-decoration: underline;
}

#holder {
	width: 640px;
	margin: 0px auto;
}

p {
	text-align: center;
}
CSS
	close(CSS_FILE);
}

sub write_html() {
	open(INDEX_FILE, ">$dst_dir/index.html");
	print INDEX_FILE <<HEADER;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Mail statistics for $host</title>
<meta http-equiv="Refresh" content="300" />
<meta http-equiv="Pragma" content="no-cache" />
<link rel="stylesheet" href="mailgraph.css" type="text/css" />
<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.5.2/jquery.min.js"></script>
<script type="text/javascript">
	function show_all_sections() {
		\$("div.section").show();
	}

	function switch_section(section_id) {
		var div = \$("#" + section_id);
		if(div.length) {
			\$("div.section").hide();
			div.show();
		}
	}

	\$(document).ready(function() {
		\$("div.section").hide();
		var section = window.location.href.slice(window.location.href.indexOf('#') + 1);
		if(section == "ALL") {
			show_all_sections();
		} else {
			switch_section(section);
		}
	});
</script>
</head>
<body>
<div id="holder">
HEADER

	print INDEX_FILE "<h1>Mail statistics for " . $host . "</h1>\n";
	print INDEX_FILE "<p>\n";

	for my $n (0..$#graphs) {
		print INDEX_FILE "<a href=\"#G_" . $n . "\" onclick=\"javascript:switch_section('G_" . $n . "')\">" . $graphs[$n]{title} . "</a>&nbsp;|&nbsp;";
	}
	print INDEX_FILE "<a href=\"#ALL\" onclick=\"javascript:show_all_sections()\">All</a></p>\n";

	$time_stamp = time;
	for my $n (0..$#graphs) {
		print INDEX_FILE "<div id=\"G_" . $n . "\" class=\"section\">\n";
		print INDEX_FILE "<h2>" . $graphs[$n]{title} . " graphs</h2>\n";
		print INDEX_FILE "<p><img src=\"mailgraph_" . $n . ".png?" . $time_stamp . "\" alt=\"" . $graphs[$n]{title} . " graph\"/><br/>\n";
		print INDEX_FILE "<img src=\"mailgraph_" . $n . "_err.png?" . $time_stamp . "\" alt=\"" . $graphs[$n]{title} . " graph\"/></p>\n";
		print INDEX_FILE "</div>\n";
	}

	print INDEX_FILE <<FOOTER;
</div>
</body></html>
FOOTER

	close(INDEX_FILE);
}

sub main() {
	unless(-e $rrd) {
		die("rrdfile doesn't exist");
	}

	unless(-e $rrd_virus) {
		die("Virus rrdfile doesn't exist");
	}

	unless(-d $dst_dir) {
		print "Creating $dst_dir\n";
		mkdir $dst_dir or die;
	}

	for my $n (0..$#graphs) {
		print "Creating mailgraph_" . $n . ".png\n"; 
		graph($graphs[$n]{seconds}, "$dst_dir/mailgraph_" . $n . ".png");

		print "Creating mailgraph_" . $n . "_err.png\n";
		graph_err($graphs[$n]{seconds}, "$dst_dir/mailgraph_" . $n . "_err.png");
	}

	print "Writing css\n";
	write_css();

	print "Writing html\n";
	write_html();

        print "Fixing permissions\n";
        `chown -R www-server:www-data '$dst_dir'`;
        `chmod -R 755 '$dst_dir'`;
}

main();
