# Deletes a cloned VM created by clone.sh.
if [ $# -le 0 ]
then
  echo "USAGE: ./deleteclone.sh vm_name [owner]"
  exit 1
fi
readonly VMNAME=$1
readonly INOWNER=$2

OWNER=$(awk "/owner = .*/{print \$3}" $VMNAME/*.vmx)
if [ ! -z "$OWNER" ]
then
  if [ "$OWNER" != "$INOWNER" ]
  then
    echo "Only $OWNER can delete this VM"
    exit 1
  fi
fi

VMID=$(vim-cmd vmsvc/getallvms | awk "/^[0-9]+ +$VMNAME /{print \$1}")
vim-cmd vmsvc/power.off $VMID
vim-cmd vmsvc/unregister $VMID
sleep 1
rm -rf $VMNAME
