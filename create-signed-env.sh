#!/bin/bash

# Default values
country="DE"
state="Bavaria"
locality="Munich"
organization="Mi439"
organizational_unit="Mi439"
common_name="Mi439"
email="Mi439@Mi439.com"

# Construct the subject line
subject="/C=${country}/ST=${state}/L=${locality}/O=${organization}/OU=${organizational_unit}/CN=${common_name}/emailAddress=${email}"

# Print the subject line
echo ""
echo "Using Subject Line:"
echo "$subject"
echo ""

# https://wiki.lineageos.org/signing_builds
rm -rf ~/.android-certs

make_key_nopass() {
  local out="$1"
  local size="${2:-2048}"

  bash <(
    sed "s/2048/${size}/;/Enter password/,+1d" ../../development/tools/make_key
  ) "$out" "$subject"
}

# Create Key
mkdir -p ~/.android-certs

for cert in bluetooth cts_uicc_2021 cyngn-app media networkstack nfc platform releasekey sdk_sandbox shared testcert testkey verity; do \
  make_key_nopass ~/.android-certs/$cert 2048
done

# Create APEX keys
cp ../../development/tools/make_key ~/.android-certs/
sed -i 's|2048|4096|g' ~/.android-certs/make_key

for apex in com.android.adbd com.android.adservices com.android.adservices.api com.android.appsearch com.android.appsearch.apk com.android.art com.android.bluetooth com.android.bt com.android.btservices com.android.cellbroadcast com.android.compos com.android.configinfrastructure com.android.connectivity.resources com.android.conscrypt com.android.crashrecovery com.android.devicelock com.android.extservices com.android.federatedcompute com.android.graphics.pdf com.android.hardware.authsecret com.android.hardware.biometrics.face.virtual com.android.hardware.biometrics.fingerprint.virtual com.android.hardware.boot com.android.hardware.cas com.android.hardware.contexthub com.android.hardware.dumpstate com.android.hardware.gatekeeper.nonsecure com.android.hardware.neuralnetworks com.android.hardware.power com.android.hardware.rebootescrow com.android.hardware.thermal com.android.hardware.threadnetwork com.android.hardware.uwb com.android.hardware.vibrator com.android.hardware.wifi com.android.health.connect.backuprestore com.android.healthconnect.controller com.android.healthfitness com.android.hotspot2.osulogin com.android.i18n com.android.ipsec com.android.media com.android.media.swcodec com.android.mediaprovider com.android.nearby.halfsheet com.android.networkstack.tethering com.android.neuralnetworks com.android.nfcservices com.android.ondevicepersonalization com.android.os.statsd com.android.permission com.android.profiling com.android.resolv com.android.rkpd com.android.runtime com.android.safetycenter.resources com.android.scheduling com.android.sdkext com.android.support.apexer com.android.telephony com.android.telephonycore com.android.telephonymodules com.android.tethering com.android.tzdata com.android.uprobestats com.android.uwb com.android.uwb.resources com.android.virt com.android.vndk.current com.android.vndk.current.on_vendor com.android.wifi com.android.wifi.dialog com.android.wifi.resources com.google.pixel.camera.hal com.google.pixel.vibrator.hal com.qorvo.uwb; do \
    make_key_nopass ~/.android-certs/$apex.certificate.override 4096

    if ! grep -q "BEGIN CERTIFICATE" ~/.android-certs/$apex.certificate.override.x509.pem; then
        echo "ERROR: Invalid cert PEM for $apex"
        head -n 5 ~/.android-certs/$apex.certificate.override.x509.pem || true
        exit 1
    fi
done

## Create vendor for keys
rm ~/.android-certs/make_key
rm -rf ../../vendor/lineage-priv
mkdir -p ../../vendor/lineage-priv
mv ~/.android-certs ../../vendor/lineage-priv/keys

if [ -f keys.mk ]; then
  cp keys.mk ../../vendor/lineage-priv/keys/keys.mk
else
  echo "ERROR: keys.mk not found next to create-signed-env.sh"
  exit 1
fi

cat <<EOF > ../../vendor/lineage-priv/keys/BUILD.bazel
filegroup(
    name = "android_certificate_directory",
    srcs = glob([
        "*.pk8",
        "*.pem",
    ]),
    visibility = ["//visibility:public"],
)
EOF

# Build Android.bp from whatever override certs exist in vendor/lineage-priv/keys
{
  echo "// Auto-generated. Do not edit."
  echo ""

  # Find all "*.override.pk8", strip suffix, unique, sorted
  while IFS= read -r base; do
    cat <<EOF
android_app_certificate {
    name: "${base}.override",
    certificate: "${base}.override",
}

EOF
  done < <(
    find ../../vendor/lineage-priv/keys -maxdepth 1 -type f -name "*.override.pk8" -printf "%f\n" \
      | sed 's/\.override\.pk8$//' \
      | sort -u
  )
} > ../../vendor/lineage-priv/keys/Android.bp

echo ""
echo "✓ Done! Now build as usual."
echo "✓ If builds aren't being signed, add '-include vendor/lineage-priv/keys/keys.mk' to your device mk file"
echo ""
echo "⚠ IMPORTANT: Make copies of your vendor/lineage-priv folder as it contains your keys!"
sleep 3
