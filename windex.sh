#!/bin/bash

a=2
b=3


if [ $# != $a ] && [ $# != $b ]; then #check that the correct number of inputs was given
	echo "Must have 2 or 3 inputs. $# given."
	return
fi

name=$1
word=$2 #read arguments

if [ $# = 3 ] && [ -d $3 ]; then
	directory=$3
else 
	directory="${PWD}/" #if no directory provided, cwd.
fi


if [ -f "${directory}${name}" ]; then #if file exists
	myFile="${directory}${name}" #read file
else 
	echo "Cannot find ${directory}${name}"
	return
fi

if ! grep ^"$word," $myFile; then #print desired line
	echo "Could not find $word in ${directory}${name}." #if not found, report
fi

return

