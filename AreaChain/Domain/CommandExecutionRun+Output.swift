import Foundation

extension CommandExecutionRun {
    /// 单项真实创建与后续计划依赖共用相同解析，不执行消费者，也不放宽外部步骤门禁。
    func creationOutput(for reference: CommandCreationReference) -> CommandObjectReference? {
        guard snapshot.items.contains(where: { $0.stamp == reference.producer }),
              units.first(where: { $0.members.contains(reference.producer.id) })?.state == .succeeded,
              let output = outputs[reference.producer.id], output.type == reference.outputType else { return nil }
        return output
    }
}
