subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val namespaceMethod = androidExt.javaClass.getMethod("getNamespace")
                val namespace = namespaceMethod.invoke(androidExt)
                if (namespace == null) {
                    val fallback = "com.example." + project.name.replace("-", "_")
                    val setNamespaceMethod = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespaceMethod.invoke(androidExt, fallback)
                }
            } catch (e: Exception) {
            }
        }
    }
}
