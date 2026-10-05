#ifndef __UAPI_LINUX_RE_KERNEL_H
#define __UAPI_LINUX_RE_KERNEL_H

#include <linux/types.h>
#include <linux/cgroup.h>
#include <linux/freezer.h>

#define MIN_USERAPP_UID     10000
#define MAX_SYSTEM_UID      2000
#define RESERVE_ORDER       17
#define WARN_AHEAD_SPACE    (1 << RESERVE_ORDER)
#define INTERFACETOKEN_BUFF_SIZE        (140)
#define PARCEL_OFFSET                   (16) /* sync with the writeInterfaceToken */
#define LINE_ERROR                      (-1)
#define LINE_SUCCESS                    (0)

enum report_type {
    BINDER,
    SIGNAL,
};
enum binder_type {
    REPLY,
    TRANSACTION,
    OVERFLOW,
};

/*
 * Backport for Linux 4.9 (CAF sdm845, 4.9.337).
 *
 * upstream (5.x+) provides cgroup_task_frozen() alongside cgroup_freezing().
 * That helper landed in commit 6b95a0d1baac ("cgroup: add
 * cgroup_task_frozen()"), which is NOT present in 4.9. On 4.9 the only
 * cgroup-freezer primitives available are:
 *   - cgroup_freezing(task)  -> include/linux/freezer.h (CONFIG_CGROUP_FREEZER)
 *   - frozen(task)          -> PF_FROZEN test bit on task->flags
 *
 * So re-express the check using the 4.9 equivalents, keeping the same
 * semantics: "is this task in a frozen cgroup subtree".
 */
static inline bool frozen_task_group(struct task_struct* task) {
#ifdef CONFIG_CGROUP_FREEZER
	return cgroup_freezing(task) || frozen(task);
#else
	return frozen(task);
#endif
}

extern void rekernel_report_no_binder_rpc_code(int type, pid_t src_pid, struct task_struct* src, pid_t dst_pid, struct task_struct* dst, bool oneway, char* rpc_name);
extern void rekernel_report(int reporttype, int type, pid_t src_pid, struct task_struct* src, pid_t dst_pid, struct task_struct* dst, bool oneway, char* rpc_name, __u32 code);

#endif /* __UAPI_LINUX_RE_KERNEL_H */
