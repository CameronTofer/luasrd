p()
{
  now="$(date +'%r')"
  printf "$(tput setaf 1)%s$(tput sgr0) | $(tput bold)$1$(tput sgr0)\n" "$now";
}

test()
{
  busted --suppress-pending .
}

test &

fswatch -r ./*.lua |
while read line
do
    p "new changes received:"
    p $line

    test &
    p "starting tests.."
done