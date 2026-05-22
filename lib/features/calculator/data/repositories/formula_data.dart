import '../../domain/models/formula_model.dart';

class FormulaData {
  static const List<Formula> formulas = [
    // Physics - Kinematics
    Formula(
      name: 'Average Velocity',
      expression: 'v = d/t',
      category: 'Kinematics',
      subject: ScienceSubject.physics,
      description: 'Velocity = Displacement / Time',
    ),
    Formula(
      name: 'Acceleration',
      expression: 'a = (v-u)/t',
      category: 'Kinematics',
      subject: ScienceSubject.physics,
      description: 'Change in velocity over time',
    ),
    Formula(
      name: 'Newton\'s Second Law',
      expression: 'F = m*a',
      category: 'Dynamics',
      subject: ScienceSubject.physics,
      description: 'Force = Mass * Acceleration',
    ),
    Formula(
      name: 'Kinetic Energy',
      expression: 'KE = 0.5*m*v^2',
      category: 'Energy',
      subject: ScienceSubject.physics,
      description: 'Energy of motion',
    ),
    Formula(
      name: 'Potential Energy',
      expression: 'PE = m*g*h',
      category: 'Energy',
      subject: ScienceSubject.physics,
      description: 'Gravitational potential energy',
    ),
    Formula(
      name: 'Ohm\'s Law',
      expression: 'V = I*R',
      category: 'Electricity',
      subject: ScienceSubject.physics,
      description: 'Voltage = Current * Resistance',
    ),
    Formula(
      name: 'Einstein\'s Energy',
      expression: 'E = m*c^2',
      category: 'Modern Physics',
      subject: ScienceSubject.physics,
      description: 'Mass-energy equivalence',
    ),

    // Chemistry
    Formula(
      name: 'Ideal Gas Law',
      expression: 'PV = nRT',
      category: 'Gases',
      subject: ScienceSubject.chemistry,
      description: 'Relationship between P, V, n, and T',
    ),
    Formula(
      name: 'Molarity',
      expression: 'M = n/V',
      category: 'Solutions',
      subject: ScienceSubject.chemistry,
      description: 'Moles of solute per liter of solution',
    ),
    Formula(
      name: 'pH Definition',
      expression: 'pH = -log(H)',
      category: 'Acids & Bases',
      subject: ScienceSubject.chemistry,
      description: 'Measure of acidity',
    ),
    Formula(
      name: 'Specific Heat Capacity',
      expression: 'q = m*c*dT',
      category: 'Thermodynamics',
      subject: ScienceSubject.chemistry,
      description: 'Heat energy calculation',
    ),
    Formula(
      name: 'Mole Calculation',
      expression: 'n = m/M',
      category: 'Stoichiometry',
      subject: ScienceSubject.chemistry,
      description: 'Moles = mass / molar mass',
    ),
  ];
}
