# fit3042a3
Perl program that gets all links from a wikipedia page, then all subsequent links from those pages

## Instructions

To run this program you'll need all the CPAN modules installed. Code for intalling all modules needed:
```
	curl -L http://cpanmin.us | perl - --sudo App::cpanminus
	sudo cpanm Regexp::Common
	sudo cpanm List::BinarySearch 
	sudo cpanm HTML::Strip
	sudo cpanm Time::HiRes "usleep";
	sudo cpanm LWP::UserAgent;
	sudo cpanm Regexp::Common;
	sudo cpanm List::BinarySearch qw(binsearch);
	sudo cpanm HTML::Strip;
	sudo cpanm HTML::Parser;
	sudo cpanm Text::ParseWords;
	sudo cpanm URI::Encode;
```

To run windex-build, enter `perl ./windex-build.pl _name_ _startUrl_ _excludeFile_ [_maxDepth_] [_dir_]`, with the square brackets arguments being optional. Example entries:
`perl ./windex-build.pl index.txt https://en.wikipedia.org/wiki/Antonio_Corell exclude.txt`
`perl ./windex-build.pl index.txt https://en.wikipedia.org/wiki/Antonio_Corell exclude.txt 3 /media/sf_FIT3042/Assignment3/output/`

The excludewords file should contain only lower case words. It will match both lower and upper case instances of the words provided. An example exclude file has been provided.


Known bugs:
The main loop currently allows links to sometimes be added to the next set of links despite having already been added. This is handled with removeDuplicates(), so no output change is caused, nor unnecessary page fetches, but in an ideal world removeDuplicates() would not be needed.


To run windex.sh, you'll need to enter the word you're looking for (case sensitive), and the file name it's in. If the file is in a different directory from windex.sh, you'll need to specify which. Examples: 

`source windex.sh index.txt word /media/sf_FIT3042/Assignment3/output/`

`source windex.sh index.txt WoRd`
