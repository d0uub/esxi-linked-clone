readonly NUMARGS=$#
readonly INFOLDER=$1
readonly OUTFOLDER=$2
readonly DESCRIPTION=$3

usage() {
  echo "USAGE: ./clone.sh Source_VM New_VM Description(replace space with underscore)"
}

main() {
  if [  $NUMARGS -gt 2 ]
  then
    usage
    exit 1
  fi

  if [  $NUMARGS -le 2 ]
  then
    usage
    exit 1
  fi

  VMFILE=`grep scsi0\:0\.fileName "$INFOLDER"/*.vmx | grep -o "[0-9]\{6,6\}"`

  mkdir "$OUTFOLDER"
  cp "$INFOLDER"/*-"$VMFILE"* "$OUTFOLDER"/
  cp "$INFOLDER"/*.vmx "$OUTFOLDER"/

  #reference snapshot
  SNAPSHOT=`grep -o "[^\"]*.vmsn" "$INFOLDER"/*.vmx | tail -1`
  if [ ! -z "$SNAPSHOT" ]
  then
  sed -i -e '/checkpoint.vmState =/s/= .*/= "..\/'$INFOLDER'\/'$SNAPSHOT'"/' $OUTFOLDER/*.vmx
  fi

  local fullbasepath=$(readlink -f "$INFOLDER")/
  cd "$OUTFOLDER"/
  sed -i '/sched.swap.derivedName/d' ./*.vmx #delete swap file line, will be auto recreated
  sed -i -e '/displayName =/ s/= .*/= "'$OUTFOLDER'"/' ./*.vmx #Change display name config value
  local escapedpath=$(echo "$fullbasepath" | sed -e 's/[\/&]/\\&/g')
  sed -i -e '/parentFileNameHint=/ s/="/="'"$escapedpath"'/' ./*-"$VMFILE".vmdk #change parent disk path

  # Forces generation of new MAC + DHCP, I think.
  sed -i '/ethernet0.generatedAddress/d' ./*.vmx
  sed -i '/ethernet0.addressType/d' ./*.vmx

  # Forces creation of a fresh UUID for the VM.  Obviates the need for the line
  # commented out below:
  #echo 'answer.msg.uuid.altered="I copied it" ' >>./*.vmx
  sed -i '/uuid.location/d' ./*.vmx
  sed -i '/uuid.bios/d' ./*.vmx

  # delete old annotation
  sed -i '/annotation *=/d' *.vmx

  # add new annotation
  sed -i -e "\$aannotation = \"$DESCRIPTION\"" *.vmx

  # Things that ghetto-esxi-linked-clones.sh did that we might want.  I can only guess at their use/value.
  #sed -i '/scsi0:0.fileName/d' ${STORAGE_PATH}/$FINAL_VM_NAME/$FINAL_VM_NAME.vmx
  #echo "scsi0:0.fileName = \"${STORAGE_PATH}/${GOLDEN_VM_NAME}/${VMDK_PATH}\"" >> ${STORAGE_PATH}/$FINAL_VM_NAME/$FINAL_VM_NAME.vmx
  #sed -i 's/nvram = "'${GOLDEN_VM_NAME}.nvram'"/nvram = "'${FINAL_VM_NAME}.nvram'"/' ${STORAGE_PATH}/$FINAL_VM_NAME/$FINAL_VM_NAME.vmx
  #sed -i 's/extendedConfigFile = "'${GOLDEN_VM_NAME}.vmxf'"/extendedConfigFile = "'${FINAL_VM_NAME}.vmxf'"/' ${STORAGE_PATH}/$FINAL_VM_NAME/$FINAL_VM_NAME.vmx

  # delete machine id
  sed -i '/machine.id/d' *.vmx

  # add machine id
  sed -i -e "\$amachine.id=$OUTFOLDER" *.vmx

  # Register the machine so that it appears in vSphere.
  FULL_PATH=`pwd`/*.vmx
  VMID=`vim-cmd solo/registervm $FULL_PATH`

  # Power on the machine.
  vim-cmd vmsvc/power.on $VMID
}

main
