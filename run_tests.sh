#!/bin/bash
set -o nounset

RET=
RET_OK=

for IT in $(find tests/ -iname \*[.]sh); do
	echo -e "\n[$0]: $IT: $(head -1 $IT)"
	echo "---------------------"
	bash $IT
	RET=$?
	RET_OK=$(grep RET $IT | sed 's/#RET=//' )
	echo "---------------------"
	echo -en "[$0]: $IT: returned $RET "
	[[ $RET -eq $RET_OK ]] && echo "(SUCCESS)" || echo "(FAILURE)"
	echo "#####################"
done
