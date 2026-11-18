"use strict";

const { Script } = require("vm");

module.exports = {
    meta: {
        type: "problem",
        schema: [],
        messages: {
            invalid: "Serialized function {{name}} is invalid as an injected expression: {{error}}. Use a function expression or arrow-function field."
        }
    },

    create(context) {
        const sourceCode = context.getSourceCode();
        const classes = new Map();

        function propertyName(node) {
            return node.computed ? node.property?.value : node.property?.name;
        }

        return {
            ClassDeclaration(node) {
                classes.set(node.id.name, node);
            },

            CallExpression(node) {
                const callee = node.callee;
                if (callee.type !== "MemberExpression" || propertyName(callee) !== "toString") {
                    return;
                }
                const member = callee.object;
                if (member.type !== "MemberExpression") {
                    return;
                }
                const ancestors = context.getAncestors();
                const isInjectedCode = ancestors.some(ancestor =>
                    ancestor.type === "Property" &&
                    (ancestor.key.name || ancestor.key.value) === "code"
                );
                if (!isInjectedCode) {
                    return;
                }
                const owner = member.object;
                const classNode = owner.type === "ThisExpression"
                    ? ancestors.slice().reverse().find(ancestor =>
                        ancestor.type === "ClassDeclaration" || ancestor.type === "ClassExpression")
                    : classes.get(owner.name);
                if (!classNode) {
                    return;
                }
                const name = propertyName(member);
                const definition = classNode.body.body.find(element =>
                    !element.computed && element.key?.name === name &&
                    element.static === (owner.type !== "ThisExpression")
                );
                if (!definition || !definition.value) {
                    return;
                }
                const functionSource = definition.type === "MethodDefinition"
                    ? sourceCode.getText(definition).replace(/^static\s+/, "")
                    : sourceCode.getText(definition.value);
                try {
                    new Script(`(${functionSource})`);
                } catch (error) {
                    context.report({
                        node,
                        messageId: "invalid",
                        data: { name, error: error.message }
                    });
                }
            }
        };
    }
};
