function camposSensibles(datos) {
  // Devuelve las rutas de los campos sensibles encontrados, sin distinguir mayúsculas
  // y recorriendo objetos y listas anidados. Uso: * match camposSensibles(response) == []
  var sensibles = ['password', 'contrasena', 'clave', 'hash', 'salt', 'token', 'secret', 'api_key'];
  var encontrados = [];
  var revisar = function(valor, ruta) {
    var tipo = karate.typeOf(valor);
    if (tipo == 'list') {
      for (var i = 0; i < valor.length; i++) {
        revisar(valor[i], ruta + '[' + i + ']');
      }
    } else if (tipo == 'map') {
      karate.forEach(valor, function(clave, v) {
        if (sensibles.indexOf(('' + clave).toLowerCase()) >= 0) {
          encontrados.push(ruta + '.' + clave);
        }
        revisar(v, ruta + '.' + clave);
      });
    }
  };
  revisar(datos, '$');
  return encontrados;
}
