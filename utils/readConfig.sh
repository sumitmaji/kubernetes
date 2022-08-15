#/bin/sh

file="./config"

if [ -f "$file" ]
then
  echo "$file found."

  while IFS='=' read -r key value
  do
    key=$(echo $key | tr '.' '_')
    eval "${key}='${value}'"
        
  done < "$file"
else
  echo "$file not found."
fi
