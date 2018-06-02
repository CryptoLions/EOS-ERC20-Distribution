#!/bin/bash
################################################################################
#
# Scrip Created by  http://CryptoLions.io
# 
# For EOS Junlge testnet
#
# https://github.com/CryptoLions/
#
################################################################################
DATA_DIR=$(pwd)/data

SNAPSHOT_URL=""
SNAPSHOT_FILE="snapshot.csv"

CUR_SYMBOL="EOS"
SUM=0
ROW=0
REQUEST_FAILED=0
REQUEST_OK=0
RETRY_TX_PAUSE=0.2 #in seconds

TO_RAM=1000   #1.0000 EOS
RAM_ASSET="0.1000 $CUR_SYMBOL"
MAX_TRANSFER=100000  #10.0000 EOS


echo "------------ Loading Distribution List -----------------"
if [[ ! -f $DATA_DIR/snapshot.csv ]]; then
    echo -ne "Downloading snapshot...\n"
    #wget $SNAPSHOT_URL -O tmp/snapshot.csv
fi

if [[ ! -f $DATA_DIR/snapshot.txt ]]; then
    csvtool col 2,3,4 $DATA_DIR/$SNAPSHOT_FILE > $DATA_DIR/snapshot.txt
    sed -i -e 's/\"//g' $DATA_DIR/snapshot.txt
    sed -i -e 's/,/ /g' $DATA_DIR/snapshot.txt
    sed -i -e 's/\.//g' $DATA_DIR/snapshot.txt
fi

TOTAL=$(wc -l < $DATA_DIR/snapshot.txt)

echo -ne "Snapshot Prepared to drop.\n"

echo "------------ Applaying Distribution List -----------------"

echo -ne "Processing snapshot.. \n"

filelines=$(cat $DATA_DIR/snapshot.txt)
STARTTIME=$(date +%s.%N)

while read line; do

    addr=($line)

    ROW=$(($ROW+1))
    EOS=${addr[2]}

    SUM=$(($SUM+$EOS))


    if [[ $EOS -le 110000 ]]; then
	#If an account has N EOS where 1.0000 < N <= 11.0000,
	#./cleos system newaccount --transfer --stake-net "0.4500 EOS" --stake-cpu "0.4500 EOS" --buy-ram-EOS "0.1000 EOS" eosio <acc> <pubkey>
	#./cleos transfer eosio <acc> "<N-1.0000> EOS”

	STAKE_NET="4500"
	STAKE_CPU="4500"
	TRANSFER=$(($EOS-10000))
    else
	#If an account has N EOS where N > 11.0000, then let X = N - 11.0000, Y = floor((X*10000)/2)/10000, Z = X - Y,
	#./cleos system newaccount --transfer --stake-net "<Y> EOS" --stake-cpu "<Z> EOS" --buy-ram-EOS "0.1000 EOS" eosio <acc> <pubkey>
	#./cleos transfer eosio <acc> "10.0000 EOS”
	
	STAKE_SUM=$(($EOS-$TO_RAM-$MAX_TRANSFER))

	STAKE_NET=$(bc <<< 'scale=0;'$STAKE_SUM'/2')
	STAKE_CPU=$(($STAKE_SUM-$STAKE_NET))
	TRANSFER=$MAX_TRANSFER

    fi


    STAKE_NET_ASSET="$(bc <<< 'scale=4;'$STAKE_NET'/10000') $CUR_SYMBOL"
    STAKE_CPU_ASSET="$(bc <<< 'scale=4;'$STAKE_CPU'/10000') $CUR_SYMBOL"


    if [[ $STAKE_NET -le 10000 ]]; then
	STAKE_NET_ASSET="0"$STAKE_NET_ASSET
    fi

    if [[ $STAKE_CPU -le 10000 ]]; then
	STAKE_CPU_ASSET="0"$STAKE_CPU_ASSET
    fi


    echo -ne "$ROW / $TOTAL : [${addr[0]}] ${addr[2]} EOS = RAM: $RAM_ASSET, STAKE_NET: $STAKE_NET_ASSET, STAKE_CPU: $STAKE_CPU_ASSET                              \r"

    #echo "RAM: $RAM_ASSET"
    #echo "STAKE_NET: $STAKE_NET_ASSET"
    #echo "STAKE_CPU: $STAKE_CPU_ASSET"
    #echo "TRANSFER: $STAKE_CPU_ASSET"



    username=${addr[0]}

    #exit
    cmd="./cleos.sh system newaccount -x 3600 --transfer --stake-net \"$STAKE_NET_ASSET\" --stake-cpu \"$STAKE_CPU_ASSET\" --buy-ram \"$RAM_ASSET\" eosio $username ${addr[1]} ${addr[1]} -f 2>&1"
    createAccount=$(./cleos.sh system newaccount -x 3600 --transfer --stake-net "$STAKE_NET_ASSET" --stake-cpu "$STAKE_CPU_ASSET" --buy-ram "$RAM_ASSET" eosio $username ${addr[1]} ${addr[1]} -f 2>&1)


    if [[ $createAccount =~ .*Error.* ]]; then
        echo "${addr[0]},${addr[1]},${addr[2]}" >> error_accounts.log
        echo $createAccount >> error_accounts_answer.log
        echo $cmd >> error_accounts_cmd.log
        echo "./cleos.sh transfer -x 3600 eosio $username \"$TRANSFER_ASSET\" \"test ERC20 Distribution\" -f 2>&1" >> error_accounts_transfer.log

	REQUEST_FAILED=$(($REQUEST_FAILED+1))
    else
	REQUEST_OK=$(($REQUEST_OK+1))
	if [[ $TRANSFER -ge 1 ]]; then
    	   
	    TRANSFER_ASSET="$(bc <<< 'scale=4;'$TRANSFER'/10000') $CUR_SYMBOL"
	    if [[ $TRANSFER -le 10000 ]]; then
		TRANSFER_ASSET="0"$TRANSFER_ASSET
	    fi

	    issueTransfer=$(./cleos.sh transfer -x 3600 eosio $username "$TRANSFER_ASSET" "test ERC20 Distribution" -f 2>&1)
    	    if [[ $issueTransfer =~ .*Error.* ]]; then
        	#Try Again with Pause
        	echo -ne "----------  TX Failed. Retry     -------------                       \r"
        	sleep $RETRY_TX_PAUSE

        	issueTransfer=$(./cleos.sh transfer -x 3600 eosio $username "$TRANSFER_ASSET" "test ERC20 Distribution" -f 2>&1)
                if [[ $issueTransfer =~ .*Error.* ]]; then
                    echo -ne "----------   TX Failed. Logged  -------------                 \r"
		    REQUEST_FAILED=$(($REQUEST_FAILED+1))
                    echo "${addr[0]},${addr[1]},${addr[2]}" >> error_transfer.log
                    echo "./cleos.sh transfer eosio -x 3600 $username \"$TRANSFER_ASSET\" \"test ERC20 Distribution\" -f 2>&1" >> error_transfer__.log
		    echo $issueTransfer >> error_transfer_.log
                fi
	    else 
		REQUEST_OK=$(($REQUEST_OK+1))
    	    fi
	fi


    fi

done < $DATA_DIR/snapshot.txt
echo "========================================================================================="



ENDTIME=$(date +%s.%N)
DIFF=$(echo "$ENDTIME - $STARTTIME" | bc)

echo "Failed : $REQUEST_FAILED"
echo "OK: $REQUEST_OK"
echo "Total Processed: "$(($REQUEST_OK+$REQUEST_FAILED))

echo -ne "Total SUM: $SUM \n\n"

echo "Time: $DIFF sec."
echo "TPS: " $(echo "scale=2; $REQUEST_OK/$DIFF" | bc)
