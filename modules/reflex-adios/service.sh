#!/system/bin/sh
# service.sh: late_start service. Runs after on boot and on property: triggers.
# Re-asserts kernel defaults (reflex governor, adios scheduler) that vendor/system init
# overwrites: init.qcom.power.rc (schedutil) and init.qcom.rc (cfq) plus qassa-iosched.rc.

log_action() {
    log -p i -t reflex-adios "$1"
}

# Re-assert reflex governor on all cpufreq policies that support it
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -d "$policy" ]; then
        gov_file="$policy/scaling_governor"
        avail_file="$policy/scaling_available_governors"
        if [ -w "$gov_file" ] && [ -r "$avail_file" ]; then
            # Check if reflex is available (space-sensitive grep for exact word)
            if grep -qw "reflex" "$avail_file" 2>/dev/null; then
                echo "reflex" > "$gov_file" 2>/dev/null && \
                    log_action "Set governor: reflex on $policy" || \
                    log_action "Failed to set governor on $policy"
            else
                log_action "Skipped $policy: reflex not in available governors"
            fi
        fi
    fi
done

# Re-assert adios scheduler on all sd* block devices that support it
for block_dev in /sys/block/sd*; do
    if [ -d "$block_dev" ]; then
        sched_file="$block_dev/queue/scheduler"
        if [ -w "$sched_file" ]; then
            # Read the scheduler list and check if adios is one of them
            sched_list=$(cat "$sched_file" 2>/dev/null)
            # The active scheduler is in brackets, e.g. "[adios] cfq" or "adios [cfq]"
            if echo "$sched_list" | grep -qw "adios" 2>/dev/null; then
                echo "adios" > "$sched_file" 2>/dev/null && \
                    log_action "Set scheduler: adios on $block_dev" || \
                    log_action "Failed to set scheduler on $block_dev"
            else
                log_action "Skipped $block_dev: adios not in available schedulers"
            fi
        fi
    fi
done

# Reset io.scheduler property so qassa-iosched.rc propagates adios instead of empty
# Setprop is generally available on rooted KSU modules; ignore failures.
setprop sys.io.scheduler "adios" 2>/dev/null
setprop persist.sys.io.scheduler "adios" 2>/dev/null
log_action "Set properties: sys.io.scheduler and persist.sys.io.scheduler to adios"

exit 0