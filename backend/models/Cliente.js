module.exports = (sequelize, DataTypes) => {
    const Cliente = sequelize.define(
        'Cliente',
        {
            id_cliente: {
                type: DataTypes.INTEGER,
                primaryKey: true,
                autoIncrement: true,
                allowNull: false,
            },
            nombre_completo: {
                type: DataTypes.STRING,
                allowNull: false,
            },
            ci: {
                type: DataTypes.STRING,
                allowNull: false,
                unique: true,
            },
        },
        {
            tableName: 'clientes',
            timestamps: true,
        }
    );

    Cliente.associate = (models) => {
    };

    return Cliente;
};
