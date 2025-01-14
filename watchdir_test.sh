#!/usr/bin/bash


while true; do
    touch ./test/hello
    echo "helloworld" > ./test/hello
    chmod +x ./test/hello
    rm ./test/hello
    
    sleep 10
done