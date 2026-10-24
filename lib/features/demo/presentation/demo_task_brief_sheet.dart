import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/demo_models.dart';
import 'widgets/demo_widgets.dart';

/// Presents a concise, human-readable overview of a submitted media task.
class DemoTaskBriefSheet extends StatelessWidget {
  const DemoTaskBriefSheet({
    required this.job,
    required this.statusLabel,
    required this.statusIcon,
    required this.statusColor,
    this.memberName,
    this.requestText,
    this.onViewOutputs,
    super.key,
  });

  final DemoMediaJob job;
  final String statusLabel;
  final IconData statusIcon;
  final Color statusColor;
  final String? memberName;
  final String? requestText;
  final VoidCallback? onViewOutputs;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final request = requestText?.trim() ?? '';
    final member = memberName?.trim() ?? '';
    final model = job.model.trim();
    final jobId = job.jobId.trim();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SizedBox(
          height: double.infinity,
          child: DemoSheetBody(
            key: const Key('demo-task-brief'),
            title: l.demoTaskBrief,
            footer: onViewOutputs == null
                ? null
                : DemoPrimaryButton(
                    key: const Key('demo-task-brief-view-outputs'),
                    label: l.demoViewOutputs,
                    onPressed: onViewOutputs,
                  ),
            child: ListView(
              padding: EdgeInsets.only(
                bottom: onViewOutputs == null ? 24 : 104,
              ),
              children: [
                _StatusCard(
                  label: statusLabel,
                  icon: statusIcon,
                  color: statusColor,
                ),
                const SizedBox(height: 16),
                _BriefSection(
                  key: const Key('demo-task-brief-request'),
                  label: _operationLabel(l, job.operation),
                  child: SelectableText(
                    request.isEmpty ? l.demoTaskDescriptionMissing : request,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: request.isEmpty
                          ? AppColors.textTertiary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (member.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    key: const Key('demo-task-brief-member'),
                    label: l.demoTaskExecutionMember,
                    value: member,
                  ),
                ],
                if (model.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    key: const Key('demo-task-brief-model'),
                    label: l.demoTaskModel,
                    value: model,
                  ),
                ],
                if (job.configRevision > 0) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    key: const Key('demo-task-brief-config'),
                    label: l.demoTaskConfiguration,
                    value: l.demoTaskConfigRevision(job.configRevision),
                  ),
                ],
                if (jobId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailRow(
                    key: const Key('demo-task-brief-id'),
                    label: l.demoTaskIdentifier,
                    value: jobId,
                    selectable: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    excludeSemantics: true,
    child: Container(
      key: const Key('demo-task-brief-status'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BriefSection extends StatelessWidget {
  const _BriefSection({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: demoSurface(context),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const Key('demo-task-brief-operation'),
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.selectable = false,
    super.key,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 3),
          if (selectable)
            SelectableText(value, style: valueStyle)
          else
            Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

String _operationLabel(AppLocalizations l, String operation) {
  final normalized = operation.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (normalized.contains('tts') || normalized.contains('speech')) {
    return l.demoTaskTts;
  }
  if (normalized.contains('music')) return l.demoTaskMusic;
  if (normalized.contains('vision')) return l.demoTaskVision;
  if (normalized.contains('video')) return l.demoTaskVideo;
  if (normalized.contains('image')) return l.demoTaskImage;
  if (normalized.contains('script')) return l.demoTaskScript;
  if (normalized.contains('text')) return l.demoTaskText;
  if (normalized.contains('audio')) return l.demoTaskAudio;
  return l.demoTaskMedia;
}
