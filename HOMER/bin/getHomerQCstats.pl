#!/usr/bin/env perl


if (@ARGV < 1) {
	print STDERR "\n\tUsage: getHomerQCstats.pl [options] -k key.txt [-d <tag dir 1> ...]\n";
	print STDERR "\n\tWill print stats to stdout\n";
	print STDERR "\n\tOptions:\n";
	print STDERR "\t\t-k <keyfile> (mapping between tag directors and alignment files)\n";
	print STDERR "\t\t-d <tagDir> [tagDir2] ... (tag directories to get stats from)\n";
	print STDERR "\t\t-chr <chr1> [chr2] ... (print tags for these chromosomes)\n";
	print STDERR "\t\t-sam <f1.sam> [f2.sam] ... (alignment files, will look for *log files)\n";
	print STDERR "\n";
	exit;
}
my %tagDirs = ();
my %mapFiles = ();
my %printChrs = ();
my @alignFiles = ();
	
my $keyFile = "";
my $tmpFile = rand() . ".tmp";
my $genome = "";


for (my $i=0;$i<@ARGV;$i++) {
	if ($ARGV[$i] eq '-k') {
		$keyFile = $ARGV[++$i];
	} elsif ($ARGV[$i] eq '-d') {
		my $bail = 0;
		while ($ARGV[++$i] !~ /^\-/) {
			my %a = ();
			$tagDirs{$ARGV[$i]} = \%a;
			if ($i>=@ARGV-1) {
				$bail = 1;
				last;
			}
		}
		last if ($bail == 1);
		$i--;

	} elsif ($ARGV[$i] eq '-sam') {
		my $bail = 0;
		while ($ARGV[++$i] !~ /^\-/) {
			my %a = ();
			push(@alignFiles, $ARGV[$i]);
			if ($i>=@ARGV-1) {
				$bail = 1;
				last;
			}
		}
		last if ($bail == 1);
		$i--;

	} elsif ($ARGV[$i] eq '-chr') {
		my $bail = 0;
		while ($ARGV[++$i] !~ /^\-/) {
			my %a = ();
			$printChrs{$ARGV[$i]} = \%a;
			if ($i>=@ARGV-1) {
				$bail = 1;
				last;
			}
		}
		last if ($bail == 1);
		$i--;
	} else {
		print STDERR "!! Do not recognize $ARGV[$i] !!\n";
		exit;
	}
}
		
if ($keyFile ne '') {
	open IN, $keyFile;
	while (<IN>) {
		chomp;
		s/\r//g;
		my @line = split /\t/;
		if (!exists($tagDirs{$line[0]})) {
			my %a = ();
			$tagDirs{$line[0]} = \%a;
		}
		$tagDirs{$line[0]}->{$line[1]} = 1;
		$mapFiles{$line[1]} = '';
	}
	close IN;
}

#get any mapping files
foreach(keys %tagDirs) {
	my $dir = $_;
	my $tagInfoFile = $dir . "/tagInfo.txt";
	open IN, $tagInfoFile;
	while (<IN>) {
		chomp;
		s/\r//g;
		while (s/\s([^\s]+?\.[bs]am)//) {
			my $samFile = $1;
			$tagDirs{$dir}->{$samFile} = 1;
			$mapFiles{$samFile} = 1;
		}
	}
}

foreach(@alignFiles) {
	$mapFiles{$_}=1;
}

my $str = '';
foreach(keys %mapFiles) {
	$str .= " \"$_\"";
}
my $mapHeader = '';
if ($str ne '') {
	#print STDERR "`getMappingStats.pl $str > $tmpFile`;\n";
	`getMappingStats.pl $str > $tmpFile`;
	open IN, $tmpFile;
	my $count= 0;
	while (<IN>) {
		$count++;
		chomp;
		s/\r//g;
		my $og = $_;
		if ($count == 1) {
			$mapHeader = $og;
			next;
		}
		my @line = split /\t/;
		if (!exists($mapFiles{$line[0]})) {
			print STDERR "Somethings wrong... $line[0]\n";
		}
		$mapFiles{$line[0]} = {g=>$line[1],t=>$line[2],ad=>$line[3],a=>$line[4],u=>$line[5],
										mm=>$line[6],un=>$line[7],p=>$line[8]};
	}
	close IN;
	`rm -f $tmpFile`;
}
			

print "Experiment Directory";
if ($mapHeader ne '') {
	print $mapHeader;
}

my @printChrs = keys %printChrs;

print "\tGenome\tTotal reads in analysis\tTotal positions in analysis";
print "\tEst. Genome Size\tReads per bp\tAvg. Reads per position\tMedian Reads per position";
print "\tAvg. Read Length\tEst. Fragment Length\tEst. Peak Size\tGC-content\tCommand";
foreach(@printChrs) {
	print "\t$_";
}
print "\n";

my $chrCountsFlag = 1;
my $norm = -1;
my $colNum = 2;
##my @data = ();
my @names = ();
my %allChr = ();
foreach(keys %tagDirs) {
	my $dir = $_;
	
	my $tagInfoFile = $dir . "/tagInfo.txt";
	unless (-e $tagInfoFile) {
		print STDERR "!!!! Could not open file $tagInfoFile!\n";
		next;
	}
	
	my $genomeVersion = '';
	my $totalTags = '';
	my $totalPositions = '';
	my $fragLength = '';
	my $peakSize = '';
	my $tbp = '';
	my $avgTbp = '';
	my $avgLen = '';
	my $gsizeEstimate = '';
	my $gc = '';
	my $cmd = '';
	my $medianTbp = '';
	my %chr =();
		
	open IN, $tagInfoFile;
	while (<IN>) {
		chomp;
		s/\r//g;
		my @line = split /\t/;
		if ($line[0] =~ /^genome/) {
			if ($line[0] =~ /genome=(.+?)$/) {
				$genomeVersion = $1;
			}
			$totalPositions = $line[1];
			$totalTags = $line[2];
		} elsif ($line[0] =~ /^fragmentLengthEstimate=(.+?)$/) {
			$fragLength = $1;
		} elsif ($line[0] =~ /peakSizeEstimate=(.+?)$/) {
			$peakSize = $1;
		} elsif ($line[0] =~ /tagsPerBP=(.+?)$/) {
			$tbp = $1;
		} elsif ($line[0] =~ /averageTagsPerPosition=(.+?)$/) {
			$avgTbp = $1;
		} elsif ($line[0] =~ /averageTagLength=(.+?)$/) {
			$avgLen = $1;
		} elsif ($line[0] =~ /gsizeEstimate=(.+?)$/) {
			$gsizeEstimate = $1;
		} elsif ($line[0] =~ /averageFragmentGCcontent=(.+?)$/) {
			$gc = $1;
		} elsif ($line[0] =~ /cmd=(.+?)$/) {
			$cmd = $1;
		} elsif ($line[0] eq 'name') {
		} else {
			#chr name
			$allChr{$line[0]}=0;
			$chr{$line[0]} = $line[$colNum];
		}
	}
	close IN;

	my $file = $dir . "/tagCountDistribution.txt";
	open IN, $file;
	while (<IN>) {
		chomp;
		s/\r//g;
		if (/Median = (\d+),/) {
			$medianTbp = $1;
			last;
		}
	}
	close IN;
	
	push(@names, $dir);	
	#push(@totals, $totalTags);	
	#push(@data, \%chr);

	print "$dir";

	if ($mapHeader ne '') {
		my $genome = '';
		my $totalReads = 0;
		my $ad = 0;
		my $a = 0;
		my $u = 0;
		my $m = 0;
		my $un = 0;
		my $aligner = '';
	
		foreach(keys %{$tagDirs{$dir}}) {
			my $f=$_;
			if (exists($mapFiles{$f})) {
				$genome = $mapFiles{$f}->{'g'};
				my $t += $mapFiles{$f}->{'t'};
				$ad += $t*cleanPercent($mapFiles{$f}->{'ad'});
				$a += $t*cleanPercent($mapFiles{$f}->{'a'});
				$u += $t*cleanPercent($mapFiles{$f}->{'u'});
				$m += $t*cleanPercent($mapFiles{$f}->{'mm'});
				$un += $t*cleanPercent($mapFiles{$f}->{'un'});
				$totalReads += $t;
				$aligner = $mapFiles{$f}->{'p'};
			}
		}
		if ($totalReads>0) {
			$ad = sprintf("%.1f",$ad/$totalReads*100) . '%' if ($ad ne '');
			$a = sprintf("%.1f",$a/$totalReads*100) . '%' if ($a ne '');
			$u = sprintf("%.1f",$u/$totalReads*100) . '%' if ($u ne '');
			$m = sprintf("%.1f",$m/$totalReads*100) . '%' if ($m ne '');
			$un = sprintf("%.1f",$un/$totalReads*100) . '%' if ($un ne '');
		}

			
		print "\t$genome\t$totalReads\t$ad\t$a\t$u\t$m\t$un\t$aligner";

	}


	print "\t$genomeVersion\t$totalTags\t$totalPositions";
	print "\t$gsizeEstimate\t$tbp\t$avgTbp\t$medianTbp";
	print "\t$avgLen\t$fragLength\t$peakSize\t$gc\t$cmd";

	foreach(@printChrs) {
		my $c = $_;
		my $v = 'NA';
		if (exists($chr{$c})) {
			$v = $chr{$c};
		}
		print "\t$v";
	}

	print "\n";

}
foreach(@alignFiles) {
	my $f = $_;
	my $genome = '';
	my $totalReads = 0;
	my $ad = 0;
	my $a = 0;
	my $u = 0;
	my $m = 0;
	my $un = 0;
	my $aligner = '';
	
	if (exists($mapFiles{$f})) {
		$genome = $mapFiles{$f}->{'g'};
		my $t += $mapFiles{$f}->{'t'};
		$ad += $t*cleanPercent($mapFiles{$f}->{'ad'});
		$a += $t*cleanPercent($mapFiles{$f}->{'a'});
		$u += $t*cleanPercent($mapFiles{$f}->{'u'});
		$m += $t*cleanPercent($mapFiles{$f}->{'mm'});
		$un += $t*cleanPercent($mapFiles{$f}->{'un'});
		$totalReads += $t;
		$aligner = $mapFiles{$f}->{'p'};
	}
	if ($totalReads>0) {
		$ad = sprintf("%.1f",$ad/$totalReads*100) . '%' if ($ad ne '');
		$a = sprintf("%.1f",$a/$totalReads*100) . '%' if ($a ne '');
		$u = sprintf("%.1f",$u/$totalReads*100) . '%' if ($u ne '');
		$m = sprintf("%.1f",$m/$totalReads*100) . '%' if ($m ne '');
		$un = sprintf("%.1f",$un/$totalReads*100) . '%' if ($un ne '');
	}

		
	print "$f\t$genome\t$totalReads\t$ad\t$a\t$u\t$m\t$un\t$aligner\n";
}


	

sub cleanPercent {
	my ($n) = @_;
	$n =~ s/\%//g;
	return '0' if ($n eq '');
	if ($n =~ /\d/) {
		return $n/100;
	} else {
		return 0;
	}
}






exit(0);
