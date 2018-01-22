#!/usr/bin/perl

use strict;
use Cwd;
use Time::HiRes "usleep";
use LWP::UserAgent;
use Regexp::Common qw/URI/;
use List::BinarySearch qw(binsearch);
use HTML::Strip;
use HTML::Parser;
use Text::ParseWords;
use URI::Encode;


# http://sandbox.mc.edu/~bennet/perl/leccode/


my $args = @ARGV;
if($args != 3 && $args != 5) {
	die "windex-build requires either 3 or 5 inputs, $args given.\n";
}
my $name = $ARGV[0];
my $startURL = $ARGV[1];
my $excludeFileName = $ARGV[2]; #read arguments
my $maxDepth; 
my $dir; #where file will be saved

if($args==5) { #if optional inputs are given, set them
	$maxDepth = min($ARGV[3], 5);
	$dir = $ARGV[4];
}
else {
	$maxDepth = 5;
	$dir = getcwd() . "/"; #sets dir to current working directory
}

open FILE, "<", $excludeFileName or die "cannot open $excludeFileName\n";
my @excludeWords = <FILE>; 
close FILE || warn "Closing $excludeFileName failed\n";


@excludeWords = sort @excludeWords; 
my @visited; #pages that have already been visited
my $currentDepth = 0;
my @visiting = ($startURL); #pages in the current depth level
my @nextURLs; #pages for the next depth level
my $delay = 200000;
my @pageURLs; #URLs in the current page
my $currentURL; #URL of current page being fetched
my @currentPage; #contains the lines of the current page
my %words = ();
my $visitCount = 0; #can't use size of visited as some pages will be added twice due to redirecting. Example: Soccer->Association Football.
my $redirectURL; #URL of page after redirect
my @currentWords; #list of words used in current page
my $word;
my $index;
my $urlList; #string of urls containing a certain word, separated by commas.
my $URL;




##loop that handles fetching of pages, when to stop and building the data structures for the pages visited and words found.
while ($currentDepth <= $maxDepth) {
	foreach $currentURL (@visiting) {
		#print "CURRENT: $currentURL\n"; #very useful for keeping track of pages being parsed
		if($visitCount <1000) { #check if the page limit has been reached
			if(index(@visited, $currentURL) != -1) {
				next; #don't load page if already visited
			}
					
			@currentPage = getPage($currentURL); #load page. Each item of @currentPage will be a line from the HTML
			$visitCount +=1; #counts the amount of pages fetched			
			
			
			$redirectURL = getRealURL(@currentPage); 

			unless($redirectURL) { 
				usleep($delay);
				print STDERR "Unrecognised wikipedia format\n"; #due to checks in other methods, this should never happen. 
				next; #skips to next url if the page beign visited isn't from wikipedia
			}
			if(index(@visited, $redirectURL) != -1 || index(@visited, $currentURL) != -1) {
				next; #skips to next url if redirected page already visited
			} 
			
			if($currentURL eq $redirectURL) { 
				@visited = push(@visited, $currentURL); #only add one version of the URL if they are the same
			}
			else {
				push(@visited, $currentURL); #add both versions if they are different
				push(@visited, $redirectURL);
			}
			
			@currentPage = trimPage(@currentPage); #remove parts of html unrelated to the article itself. This saves computation time when parsing.
			@pageURLs = getURLs(@currentPage); #get list of wiki URLs in article
			@currentWords = getWords(@currentPage); #get list of words in article
			foreach $word (@currentWords) {
				$index = binsearch {$a cmp $b} lc("$word\n"), @excludeWords; #don't add the word if it's in excludewords
				if($index == ' ') { #word not in excludeWords
					if(exists $words{$word}) {
						$urlList = $words{$word};
						if(index($urlList, $redirectURL) != -1) { next; } #don't add url that is already attributed to a word. Can happed when word exists multiple times in page.
						if($currentURL eq $redirectURL) { #add currentURL and the redirected version to the URL list as per the formatting instructions
							$urlList = $urlList . ',' . $redirectURL; 
						}
						else {
							$urlList = $urlList . ',' . $redirectURL . ',' . $currentURL;
						}
						$words{$word} = $urlList;
					}
					else {	
						if($currentURL eq $redirectURL) {
							$urlList = $redirectURL;
						}
						else {
							$urlList = $redirectURL . ',' . $currentURL;
						}
						$words{$word} = $urlList;
					}
				}
			}		
			foreach $URL (@pageURLs) {  #add URLs to list of URLs to be parsed next (given that they don't appear in @visited or @visiting, or have already been added)
				if($URL eq $redirectURL || $URL eq $currentURL) { next; } #don't add current page to list of next pages to parse
				if(index(@visited, $URL) == -1 && index(@nextURLs, $URL) == -1 && index(@visiting, $URL) == -1) {
					if(isWikiLink($URL)) {
						push(@nextURLs, $URL);
					}				
				}
					
			}
			
		}	
		else {
			print "Exceeded 1000 pages visited.\n"; #exit on reaching 1000. This will still output the index file.
			last;
		}

	usleep($delay); #0.2 second delay

	}
	@visiting = ();
	@visiting = @nextURLs; #set the list of pages currently being visited to the list of pages to be visited next (next level of wiki depth)
	@visiting = removeDuplicates(@visiting); #there is a bug in the code that still allows for some duplicate URLs to get into @nextURLs. This takes care of that.
	#print"End of depth level $currentDepth\n"; #very useful for keeping track of pages being parsed
	#print "size: " . scalar @visiting. " \n"; #good for estimating 
	$currentDepth++;
	@nextURLs = ();
}


my $key;
my $path = $dir . $name; #path to file

open my $fh, ">", $path or die "cannot write $name\n";
foreach $key (keys %words) {
	print $fh "$key,$words{$key}\n" #format output
}
close $fh || warn "Closing $name failed\n";


##removeDuplicates: only leaves one of each item in the given list.
##Params: the list to be checked
##Returns: the given list, minus any duplicates

sub removeDuplicates { #http://stackoverflow.com/questions/7651/how-do-i-remove-duplicate-items-from-an-array-in-perl
    my %seen;
    grep !$seen{$_}++, @_;
}



##getURLs: gets all the wikipedia URLs in the given list
##Params: the list to be checked, where each item is a line of wikipedia HTML
##Returns: a list of all links found in the given list

sub getURLs{ #gets all links from given string list
	my @lines = @_;
	my @links;
	my @lineLink = ();
	my $line;
	foreach $line (@lines) { #get the links from each line
		@lineLink = getWikiLinks($line);
		if(scalar @lineLink != 0) { #only add link to list if some were found
			push(@links, @lineLink);
		}
	}
	return @links;
}


##min: identifies which of the two entries is smaller
##Params: two numbers
##Returns: the smaller of the two numbers
sub min{
	my ($first, $second) = @_;
	if($first>$second) {
		return $second;
	}
	else {
		return $first;
	}

}


##isWikiLink: checks if a given URL is a wikipedia URL
##Params: a URL 
##Returns: a boolean, identifying if the link is a wikipedia URL
sub isWikiLink{
	my ($link) = @_;
	my $wiki = "wikipedia.org"; #still allows for other languages of wikipedia
	if(index($link, $wiki) == -1) {
		return undef;
	}
	return 1;
}



##getRealURL: checks the wikipedia url of the given page
##Params: an untrimmed page, as an array seperated by lines
##Returns: the URL of the page after redirecting. This could be the same as the URL used to get to the page.
sub getRealURL {
	my @lines = @_;
	
	my $signalURL = qq{<link rel="canonical"}; #wikipedia's way of storing a pages main URL
	my $line; #string, line that contains the wikipedia page's real link
	my $index =0;
	my $found = 0; #bool
	my $relevantLine;
	my $URL;
	foreach $line (@lines) { #check each line for the canonical signal
		if(index($line, $signalURL) != -1) {
			$relevantLine = $line;
			$found = 1;			
			last;		
		}
		$index++;
	}
		
	if($found) {
		$URL = getLink($relevantLine);
	}
	else {
		return undef;
	}
	return $URL;
}


##getLink: gets URI out of a line
##Params: a HTML line
##Returns: URI link, or undef if none found
sub getLink { #gets the link out of a line
	my ($line) = @_;
	my ($uri) = $line =~ /$RE{URI}{-keep}/;
	my $len = length $uri;
	
	if($len < 3) { #invalid link found
		return undef;	
	}
	return $uri;
}

##getWikiLinks: gets all wikipedia links from the line provided
##Params: a HTML line
##Returns: a list of normalised links 
sub getWikiLinks {
	my $uri = URI::Encode->new( { encode_reserved => 0 } );
	my ($line) = @_;
	my $link;
	my @links;
	if(index($line, "a href") == -1) {
		return undef;
	}
	my $wiki = qq{https://en.wikipedia.org};
	while($line =~ s/<a\shref\=\"([^\"]+)\"\s//i) { 
		if(index($1, "/wiki/") == 0 && index($1, ":") == -1) {  #only reads wiki pages that don't belong to a category (like edit, history, etc)
			$link = $wiki . $1;
		}
		if (length $link >= 4) { 
			push(@links, $link);
		}
	}
	
	foreach $link (@links) { 
		$link = $uri->decode($link);
		$link =~ s/\#.*//;
		$link =~ s/\?.*//;
	}

	
	

	return @links;
}


##getWords: gets all the words from the html page given. Each word is at least 3 alphabet characters, separated by whitespace 
##Params: a HTML page, as a list of lines
##Returns: list of words
sub getWords{
	my @lines = @_;
	my $cleanText;
	my @cleanLines;
	my $line; 
	my $hs = HTML::Strip->new();
	my @words;
	my $word;
	my @currWords;

	foreach $line (@lines) { #get plain text
		$cleanText = $hs->parse($line);
		push(@cleanLines, $cleanText);
}
	foreach $line (@cleanLines) {
		@currWords = split /\s/, $line;
		foreach $word (@currWords) {
			$word =~ s/[^a-zA-Z]+//;
			if(index(@words, $word) == -1) {
				if(length $word >2) { #words must be minimum 3 characters for this implementation
					push(@words, $word);
				}
			}
		}
	}
	
	return @words;

}


##trimPage: removes HTML lines before and after the article
##Params: a HTML page, as a list of lines
##Returns: trimmed HTML page, as a list of lines
sub trimPage { #only get data from main article
	my (@lines) = @_;
	my $index = 0;
	my $line;
	my $articleStart = qq{<div id="mw-content-text" lang="en" dir="ltr" class="mw-content-ltr"><p>};

	foreach $line (@lines) { #remove everything up to article
		if(index($line, $articleStart) != -1) {
			splice(@lines, @lines-$index);
			last;		
		}
		$index++;
	}	

	$index = 0; #return index to the start, as the first $index lines have been removed
	my $referenceLine = qq{<span class="mw-headline" id="References">}; #avoid reading references, we only want links to wikipedia sources

	foreach $line (@lines) { #remove everything from the start of the references
		if(index($line, $referenceLine) != -1) {
			splice(@lines,-1 * $index);
			last;		
		}
		$index++;
	}	
	return @lines;
}

##getPage: fetches page of given URL. No check is done on whether or not it's a wikipedia page in this method.
##Params: a URL
##Returns: HTML page, as a list of lines
sub getPage {
	my ($URL) = @_;
	my $ua = LWP::UserAgent->new();
	my $page = $ua->get($URL);
	my $content = $page->content;
	my @contentLines =  split /\n/, $content;

	return @contentLines; #returns an array where each item is a line of the html file	
}
