class VariableAssignment {
  late String variableName;
  late bool isNewDeclaration;
  bool isGlobal;

  VariableAssignment(this.variableName, this.isNewDeclaration, {this.isGlobal = false});

  // Default constructor for serialization
  VariableAssignment.defaultConstructor() : variableName = '', isNewDeclaration = false, isGlobal = false;

  @override
  String toString() {
    return "VarAssign to $variableName";
  }
}
