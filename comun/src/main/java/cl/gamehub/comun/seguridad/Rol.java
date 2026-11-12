package cl.gamehub.comun.seguridad;

/**
 * Roles del caso. El Visitante no tiene cuenta: es quien navega sin token.
 *
 * <p>Equivalencia con los nombres de la pauta de la EP3 (los valores del enum no cambian porque
 * viajan dentro del JWT): ADMIN = Administrador, OPERADOR = Vendedor, CLIENTE = Cliente. La
 * interfaz muestra el nombre de la pauta, no el del enum.</p>
 */
public enum Rol {
    ADMIN,
    OPERADOR,
    CLIENTE
}
